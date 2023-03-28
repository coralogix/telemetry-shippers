# Fluent-bit-HTTP manifest files
#### Please read the [main README](https://github.com/coralogix/telemetry-shippers/blob/master/README.md) before following this chart installation.

Fluent-Bit is a lightweight data shipper, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluent-Bit shipper, together with the http output plugin to ship the logs to the Coralogix platform.

## Installation 
In order to specify important environment variables, please create a configmap:
```yaml
---
## fluentbit-env-cm.yaml:
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: fluent-bit
    app.kubernetes.io/instance	: fluent-bit-http
  name: fluent-bit-env
data:
  ENDPOINT: ingress.coralogix.com
  LOG_LEVEL: error
```
Note: the configmap name is important and is being used by the daemonSet.  
change 'ENDPOINT' according to your logs endpoint from the table below.

And apply it:
```bash
kubectl apply -f fluentbit-env-cm.yaml
```

Next apply the manifest files in this directory:
```bash
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-cm.yaml
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-rbac.yaml
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-svc.yaml
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-ds.yaml
```
The output should be :
```bash
configmap/fluent-bit created
configmap/fluent-bit-http-crxluascript created
daemonset.apps/fluent-bit created
serviceaccount/fluent-bit created
clusterrole.rbac.authorization.k8s.io/fluent-bit created
clusterrolebinding.rbac.authorization.k8s.io/fluent-bit created
service/fluent-bit created
```

If you have prometheus-operator installed you can also install this service monitor resource:
```bash
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-svc-monitor.yaml
```

## Modifying applicationName and subsystemName

By default we use the field `kubernetes.namespace_name` as the applicationName and `kubernetes.container_name` as the subsystemName.

### Dynamic
To modify these values and use another field as the value of applicationName and subsystemName modify the `fluent-bit-http-crxluascript` configmap.
For example given this log structure:
```yaml
{
	"kubernetes": {
		"container_name": "generator",
		"namespace_name": "default",
		"pod_name": "generator-app-589dbdc98-ghz8j",
		"container_image": "chentex/random-logger:latest",
		"container_image_id": "docker-pullable://chentex/random-logger@sha256:7cae589926ce903c65a853c22b4e2923211cc19966ac8f8cc533bbcff335ca39",
		"pod_id": "330ta782-a1ab-4daa-b3fa-5eb3f3d07fe0",
		"pod_ip": "177.17.0.4",
		"host": "minikube",
		"labels": {
			"app": "generator",
		}
	},
	"log": "2022-12-11T16:43:15+0000 DEBUG This is a debug log that shows a log that can be ignored.n",
	"stream": "stdout",
	"time": "2022-12-11T16:43:15.906733172Z",
}
```
We could use the 'app' label from the kubernetes object as our subsystemName.
To achive that we modify the script.lua and supply the wanted field in this format: record.json.<field_as_json_path>
```yaml
removed for brevity...
    new_record["subsystemName"] = record.json.kubernetes.labels.app
removed for brevity...
```
Note: as this script run on all logs make sure to use a field that is present in all the logs or add if/else logic to the lua script.

### Static
To modify these values and use a hard-coded value as the value of applicationName and subsystemName modify the `fluent-bit-http-crxluascript` configmap.
For example if we want all logs to have the 'my-awesome-app' as the applicationName,
we modify the script.lua:
```yaml
removed for brevity...
    new_record["applicationName"] = "my-awesome-app"
removed for brevity...
```


## Removal

To remove all resources created with manifest files use these commands:
```bash
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-cm.yaml
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-rbac.yaml
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-svc.yaml
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluent-bit/k8s-manifest/fluentbit-ds.yaml
kubectl delete -f fluentbit-env-cm.yaml
```

The output should be :
```bash
configmap "fluent-bit" deleted
configmap "fluent-bit-http-crxluascript" deleted
daemonset.apps "fluent-bit" deleted
serviceaccount "fluent-bit" deleted
clusterrole.rbac.authorization.k8s.io "fluent-bit" deleted
clusterrolebinding.rbac.authorization.k8s.io "fluent-bit" deleted
service "fluent-bit" deleted
```
## Coralogix Endpoints

| Region  | Logs Endpoint
|---------|------------------------------------------|
| EU      | `ingress.coralogix.com`                      |
| EU2     | `ingress.eu2.coralogix.com`                  |
| US      | `ingress.coralogix.us`                       |
| SG      | `ingress.coralogixsg.com`                    |
| IN      | `ingress.coralogix.in`                       |


## Dashboard
Under the `dashboard` directory, there is a Fluent-Bit Grafana dashboard that Coralogix supplies.
Please see [the dashboard README](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluent-bit/dashboard/README.md) for installation instructions.