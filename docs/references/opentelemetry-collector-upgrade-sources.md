# OpenTelemetry Collector upgrade sources

Use these sources when selecting the next Collector version and when tracing regressions.

## Release selection

- Collector distribution releases:
  - https://github.com/open-telemetry/opentelemetry-collector-releases/releases
- Collector core releases:
  - https://github.com/open-telemetry/opentelemetry-collector/releases
- Collector contrib releases:
  - https://github.com/open-telemetry/opentelemetry-collector-contrib/releases

## Regression isolation

Clone and inspect the exact release tags involved:

```bash
git clone git@github.com:open-telemetry/opentelemetry-collector.git
git clone git@github.com:open-telemetry/opentelemetry-collector-contrib.git

git -C opentelemetry-collector fetch --tags
git -C opentelemetry-collector-contrib fetch --tags

git -C opentelemetry-collector checkout vX.Y.Z
git -C opentelemetry-collector-contrib checkout vX.Y.Z
```

Compare against the previous working tag:

```bash
git -C opentelemetry-collector log --oneline vOLD...vNEW
git -C opentelemetry-collector-contrib log --oneline vOLD...vNEW
git -C opentelemetry-collector diff vOLD...vNEW
git -C opentelemetry-collector-contrib diff vOLD...vNEW
```

## Known example

Internal telemetry metric-name drift seen during validation against Collector `0.152.1` included:

- core commit `24aecacf1c047f85ab3a204008aecb8dda6c4d12`
  - `[service/telemetry] Fix Prometheus config defaults mismatch when host is explicitly set (#15027)`
- core commit `b5c5a1eaa39c4cdbddc9a04e9e57f8d439a4fb12`
  - `[exporter/exporterhelper] Add per-signal in-flight request metrics (#15014)`
