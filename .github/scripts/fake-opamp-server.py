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
    out = {'agent_health': None, 'instance_uid': None,
           'remote_config_status': False, 'effective_config': False,
           'package_statuses': False, 'agent_description': False}
    try:
        for field, _wtype, val in iter_fields(body):
            if field == 1 and isinstance(val, bytes):
                out['instance_uid'] = val.hex()
            elif field == 3 and isinstance(val, bytes):
                health = {}
                for f2, _wt2, v2 in iter_fields(val):
                    if f2 == 1 and not isinstance(v2, bytes):
                        health['healthy'] = bool(v2)
                    elif f2 == 3 and isinstance(v2, bytes):
                        health['last_error'] = v2.decode('utf-8', 'replace')[:500]
                    elif f2 == 4 and isinstance(v2, bytes):
                        # ComponentHealth: field 1 = component name, 2=healthy, 3=error
                        comps = []
                        for f3, _wt3, v3 in iter_fields(v2):
                            if f3 == 1 and isinstance(v3, bytes):
                                comps.append(v3.decode('utf-8', 'replace'))
                        health['components_reporting'] = comps
                out['agent_health'] = health
            elif field == 6:
                out['effective_config'] = True
            elif field == 7:
                out['remote_config_status'] = True
            elif field == 8:
                out['package_statuses'] = True
            elif field == 9:
                out['agent_description'] = True
    except Exception as exc:  # noqa: BLE001 - record and keep serving
        out['parse_error'] = str(exc)
    return out


def build_server_to_agent(offer_remote_config: bool) -> bytes:
    """ServerToAgent with an optional remote_config offering."""
    inner = b''
    if offer_remote_config:
        # config_map: field 2 -> config_file (field 1) -> body (field 2)
        cfg_file = b'\x12' + varint_bytes(len(REMOTE_CONFIG_BODY)) + REMOTE_CONFIG_BODY
        config_map = b'\x0a' + varint_bytes(len(cfg_file)) + cfg_file
        remote_cfg = b'\x0a' + varint_bytes(len(CONFIG_HASH)) + CONFIG_HASH
        remote_cfg += b'\x12' + varint_bytes(len(config_map)) + config_map
        inner = b'\x1a' + varint_bytes(len(remote_cfg)) + remote_cfg
    return inner


def varint_bytes(n: int) -> bytes:
    out = b''
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out += bytes([b | 0x80])
        else:
            return out + bytes([b])


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    server_version = 'FakeOpAMP/1.0'

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b''
        parsed = parse_agent_to_server(body)
        parsed['ts'] = time.time()
        parsed['path'] = self.path
        with open(STATE_PATH, 'a') as f:
            f.write(json.dumps(parsed) + '\n')

        # Offer remote config on the first report from each connection so the
        # full lifecycle (status reporting incl. remote_config_status) runs.
        offer = parsed['remote_config_status'] is False
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
        payload = {
            'connections': len(reports),
            'health_reports': len(healths),
            'healthy_reports': sum(1 for h in healths if h.get('healthy')),
            'ever_unhealthy': any(not h.get('healthy') for h in healths),
            'last_agent_health': healths[-1] if healths else None,
            'agent_description_seen': any(r.get('agent_description') for r in reports),
            'effective_config_seen': any(r.get('effective_config') for r in reports),
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
    ThreadingHTTPServer(('0.0.0.0', port), Handler).serve_forever()
