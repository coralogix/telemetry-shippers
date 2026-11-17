#!/usr/bin/env python3
"""Fake OpAMP server for the supervisor-mode CI smoke test.

Speaks the HTTP OpAMP protocol well enough for the supervisor to connect and
report agent status, and records every AgentHealth report it receives so the
CI job can assert on them (protocol-grade liveness signal instead of log
greps).

Wire format, decoded by hand (no protobuf dependency):
  AgentToServer (message type 1, length-delimited):
    field 1: instance_uid  (bytes)
    field 3: agent_health  (message AgentHealth):
      field 1: healthy            (varint)
      field 2: start_time_unix_nano (fixed64)
      field 3: last_error         (string)
      field 4: status             (message ComponentHealth)
    field 6: effective_config    (message)
    field 7: remote_config_status(message)
    field 8: package_statuses    (message)
    field 9: agent_description   (message)

  ServerToAgent (message type 2, length-delimited):
    field 3: remote_config (message): field 1 = config_hash (bytes),
      field 2 = config_map (message): field 1 = config_file (message):
      field 2 = body (bytes)
Responses are wrapped per the OpAMP HTTP transport: response body is a
length-delimited ServerToAgent message; Content-Type is
application/x-protobuf, and the response to the first request carries the
instance uid echoed via the Agent-Instance-Id header when present.
"""
import json
import os
import struct
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE_PATH = sys.argv[2] if len(sys.argv) > 2 else '/tmp/fake-opamp-state.json'

# A trivial but valid collector config the server hands out when the agent
# asks for remote config. Keeps default pipeline; enables nothing new.
REMOTE_CONFIG_BODY = b"""extensions:
  health_check:
    endpoint: 0.0.0.0:13133
receivers:
  nop:
processors:
  memory_limiter:
    check_interval: 5s
    limit_mib: 512
exporters:
  nop:
service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [nop]
      processors: [memory_limiter]
      exporters: [nop]
    metrics:
      receivers: [nop]
      processors: [memory_limiter]
      exporters: [nop]
    logs:
      receivers: [nop]
      processors: [memory_limiter]
      exporters: [nop]
"""
CONFIG_HASH = bytes(range(16))


def read_varint(data: bytes, pos: int):
    result = 0
    shift = 0
    while True:
        b = data[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, pos
        shift += 7


def iter_fields(msg: bytes):
    """Yield (field_number, wire_type, value_bytes) for a protobuf message."""
    pos = 0
    while pos < len(msg):
        key, pos = read_varint(msg, pos)
        field, wtype = key >> 3, key & 7
        if wtype == 0:  # varint
            val, pos = read_varint(msg, pos)
            yield field, wtype, val
        elif wtype == 1:  # fixed64
            yield field, wtype, msg[pos:pos + 8]
            pos += 8
        elif wtype == 2:  # length-delimited
            ln, pos = read_varint(msg, pos)
            yield field, wtype, msg[pos:pos + ln]
            pos += ln
        elif wtype == 5:  # fixed32
            yield field, wtype, msg[pos:pos + 4]
            pos += 4
        else:
            raise ValueError(f'unsupported wire type {wtype}')


def parse_agent_to_server(body: bytes) -> dict:
    # Field numbers verified against opamp-go (opamp.proto) and validated
    # against the real opamp-go client (see PR #1112 review round):
    # AgentToServer: 1 instance_uid, 2 sequence_num, 3 agent_description,
    # 4 capabilities, 5 agent_health, 6 effective_config,
    # 7 remote_config_status, 8 package_statuses, 9 agent_disconnect.
    out = {'agent_health': None, 'instance_uid': None, 'sequence_num': None,
           'capabilities': None, 'remote_config_status': None,
           'effective_config': False, 'package_statuses': False,
           'agent_description': False, 'agent_disconnect': False,
           'parse_error': None}
    try:
        for field, _wtype, val in iter_fields(body):
            if field == 1 and isinstance(val, bytes):
                out['instance_uid'] = val.hex()
            elif field == 2 and not isinstance(val, bytes):
                out['sequence_num'] = val
            elif field == 3 and isinstance(val, bytes):
                out['agent_description'] = True
            elif field == 4 and isinstance(val, bytes):
                out['capabilities'] = True
            elif field == 5 and isinstance(val, bytes):
                # AgentHealth: 1 healthy, 2 start_time_unix_nano (fixed64),
                # 3 last_error, 4 status (string), 6 component health list.
                health: dict = {'healthy': False}
                for f2, _w2, v2 in iter_fields(val):
                    if f2 == 1 and not isinstance(v2, bytes):
                        health['healthy'] = bool(v2)
                    elif f2 == 3 and isinstance(v2, bytes):
                        health['last_error'] = v2.decode('utf-8', 'replace')[:500]
                    elif f2 == 4 and isinstance(v2, bytes):
                        health['status'] = v2.decode('utf-8', 'replace')
                    elif f2 == 6 and isinstance(v2, bytes):
                        # ComponentHealth: field 1 = component id
                        for f3, _w3, v3 in iter_fields(v2):
                            if f3 == 1 and isinstance(v3, bytes):
                                health.setdefault('components', []).append(
                                    v3.decode('utf-8', 'replace'))
                out['agent_health'] = health
            elif field == 6:
                out['effective_config'] = True
            elif field == 7 and isinstance(val, bytes):
                # RemoteConfigStatus: 1 last_remote_config_hash, 2 status,
                # 3 error_message. Status: UNSET=0 APPLYING=1 APPLIED=2 FAILED=3.
                hash_ = b''
                status = 0
                for f2, _w2, v2 in iter_fields(val):
                    if f2 == 1 and isinstance(v2, bytes):
                        hash_ = v2
                    elif f2 == 2 and not isinstance(v2, bytes):
                        status = v2
                out['remote_config_status'] = {'hash': hash_.hex(), 'status': status}
            elif field == 8:
                out['package_statuses'] = True
            elif field == 9:
                out['agent_disconnect'] = True
    except Exception as exc:  # noqa: BLE001 - record loudly in /status
        out['parse_error'] = str(exc)
    return out


def ld(field: int, payload: bytes) -> bytes:
    """Length-delimited protobuf field: tag + varint length + payload."""
    return varint_bytes((field << 3) | 2) + varint_bytes(len(payload)) + payload


def build_server_to_agent(offer_remote_config: bool) -> bytes:
    """ServerToAgent with an optional remote_config offering.

    Encoding validated against the real opamp-go client (the naive
    AgentConfigMap layout of a first draft failed proto.Unmarshal; this one
    reaches OnMessage with the right body and gets remote_config_status
    echoed with our hash):
      ServerToAgent.remote_config (3) -> AgentRemoteConfig:
        config (1) -> AgentConfigMap:
          config_map (1) -> map entry: key (1, empty) -> AgentConfigObject:
            body (1), content_type (2)
        config_hash (2)
    """
    if not offer_remote_config:
        return b''
    obj = ld(1, REMOTE_CONFIG_BODY) + ld(2, b'text/yaml')
    entry = ld(1, b'') + ld(2, obj)
    config = ld(1, entry)
    remote = ld(1, config) + ld(2, CONFIG_HASH)
    return ld(3, remote)


def varint_bytes(n: int) -> bytes:
    out = b''
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out += bytes([b | 0x80])
        else:
            return out + bytes([b])


class DualStackServer(ThreadingHTTPServer):
    address_family = __import__('socket').AF_INET6
    daemon_threads = True


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    server_version = 'FakeOpAMP/1.0'

    def read_body(self):
        # opamp-go may send chunked request bodies; BaseHTTPRequestHandler
        # does not decode them.
        if 'chunked' in self.headers.get('Transfer-Encoding', '').lower():
            out = b''
            while True:
                size = int(self.rfile.readline().split(b';')[0].strip() or b'0', 16)
                if size == 0:
                    while self.rfile.readline().strip():
                        pass  # trailing headers
                    return out
                out += self.rfile.read(size)
                self.rfile.read(2)  # CRLF after each chunk
        length = int(self.headers.get('Content-Length', 0))
        return self.rfile.read(length) if length else b''

    def do_POST(self):
        body = self.read_body()
        parsed = parse_agent_to_server(body)
        parsed['ts'] = time.time()
        parsed['path'] = self.path
        with open(STATE_PATH, 'a') as f:
            f.write(json.dumps(parsed) + '\n')

        # Remote config stays off by default: applying a full config replaces
        # the supervisor-injected agent config (opamp extension included) and
        # the apply lifecycle never completes in CI. Offering it is the
        # follow-up's job (poisoned-config RED proof) - see review round.
        offer = os.environ.get('FAKE_OPAMP_OFFER_REMOTE_CONFIG') == '1'
        resp = build_server_to_agent(offer_remote_config=offer)
        self.send_response(200)
        self.send_header('Content-Type', 'application/x-protobuf')
        self.send_header('Content-Length', str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

    def do_GET(self):
        # Status/debug endpoints for the CI job and humans.
        reports = []
        try:
            with open(STATE_PATH) as f:
                reports = [json.loads(line) for line in f if line.strip()]
        except FileNotFoundError:
            pass
        healths = [r['agent_health'] for r in reports if r.get('agent_health')]
        # ever_unhealthy ignores pre-first-healthy reports: the supervisor
        # publishes healthy=false by design before the collector's first
        # health report lands (publishLastReportedHealth, supervisor.go).
        uids = {r.get('instance_uid') for r in reports if r.get('instance_uid')}
        rcs_list = [r['remote_config_status'] for r in reports
                    if isinstance(r.get('remote_config_status'), dict)]
        payload = {
            'connections': len(reports),
            'distinct_instance_uids': len(uids),
            'health_reports': len(healths),
            'healthy_reports': sum(1 for h in healths if h.get('healthy')),
            'ever_unhealthy': any(not h.get('healthy')
                                  for h in healths[healths.index(next(
                                      h for h in healths if h.get('healthy'))):])
            if any(h.get('healthy') for h in healths) else False,
            'last_agent_health': healths[-1] if healths else None,
            'agent_description_seen': any(r.get('agent_description') for r in reports),
            'effective_config_seen': any(r.get('effective_config') for r in reports),
            'remote_config_status': rcs_list[-1] if rcs_list else None,
            'parse_errors': sum(1 for r in reports if r.get('parse_error')),
        }
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):  # noqa: A002 - stdlib signature
        pass  # keep CI logs clean


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4320
    if len(sys.argv) <= 2:
        STATE_PATH = f'/tmp/fake-opamp-{port}.jsonl'
    open(STATE_PATH, 'w').close()  # truncate per-run state
    print(f'fake OpAMP server on :{port}, state at {STATE_PATH}', flush=True)
    # Dual-stack: docker's published ports accept v4 and v6; an AF_INET-only
    # bind leaves the v6 side resetting connections (curl "connection reset").
    DualStackServer(('::', port), Handler).serve_forever()
