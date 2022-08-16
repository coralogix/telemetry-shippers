---
**NOTE**

The Open Telemetry Coralogix exporter requires the Coralogix private key. Therefore the following secret must be created: 

* The `private key` appears under 'Data Flow' --> 'API Keys' in Coralogix UI.

```bash
kubectl create secret generic coralogix-otel-privatekey \
  -n <the-namespace-of-the-release> \
  --from-literal=PRIVATE_KEY=<coralogix-private-key>
```

The created secret should look like this:
```yaml
apiVersion: v1
data:
  PRIVATE_KEY: <encrypted-private-key>
kind: Secret
metadata:
  name: coralogix-otel-privatekey
  namespace: <the-release-namespace>
type: Opaque
```

---