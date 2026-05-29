# E2E validation reference

Downstream validation chart:

- `otel-integration/k8s-helm`

E2E entrypoint:

- `otel-integration/k8s-helm/e2e-test/run-all.sh`

Typical local commands:

```bash
helm dependency update otel-integration/k8s-helm
otel-integration/k8s-helm/e2e-test/run-all.sh
```

This repository is the validation surface.

Do not change downstream tests unless explicitly requested.
