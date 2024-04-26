# Fluentd-HTTP manifest files

#### Please read the [main README](https://github.com/coralogix/telemetry-shippers/blob/master/README.md) before following this chart installation.

Fluentd is a flexible data shipper with many available plugins and capabilities, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluentd shipper, together with the http output plugin to ship the logs to the Coralogix platform.

## Installation

In order to specify important environment variables, please create a configmap:

```yaml
---
## fluentd-env-cm.yaml:
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: fluentd
    app.kubernetes.io/instance: fluentd-http
  name: fluentd-env
data:
  ENDPOINT: ingress.coralogix.com
  LOG_LEVEL: error
```

Note: the configmap name is important and is being used by the daemonSet.

change 'ENDPOINT' according to your logs endpoint from the table below.

And apply it:

```bash
kubectl apply -f fluentd-env-cm.yaml -n monitoring
```

Next apply the manifest files in this directory:

```bash
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-cm.yaml -n monitoring
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-rbac.yaml -n monitoring
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-svc.yaml -n monitoring
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-ds.yaml -n monitoring
```

The output should be :

```bash
configmap/fluentd-prometheus-conf created
configmap/fluentd-systemd-conf created
configmap/fluentd-config created
configmap/fluentd-main created
daemonset.apps/fluentd-http created
serviceaccount/fluentd-http created
clusterrole.rbac.authorization.k8s.io/fluentd-http created
clusterrolebinding.rbac.authorization.k8s.io/fluentd-http created
servicemonitor.monitoring.coreos.com/fluentd-http created
service/fluentd-http created
```

If you have prometheus-operator installed you can also install this service monitor resource:

```bash
kubectl apply -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-svc-monitor.yaml -n monitoring
```

## Modifying applicationName and subsystemName

By default we use the field `kubernetes.namespace_name` as the applicationName and `kubernetes.container_name` as the subsystemName.

### Dynamic

To modify these values and use another field as the value of applicationName and subsystemName modify the `fluentd-config` configmap and specifically the `coralogix.conf` key.
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
To achive that we modify the 'record_transformer' filter:

```
<filter *.containers.**>
  @type record_transformer
  enable_ruby true
  auto_typecast true
  renew_record true
  <record>
    privateKey "#{ENV['PRIVATE_KEY']}"
    applicationName ${record.dig("kubernetes", "namespace_name")} 
    subsystemName ${record.dig("kubernetes", "labels", "app")} # we use ruby dig function to get a value without exception.
    computerName ${record.dig("kubernetes", "host")}
    timestamp ${time.strftime('%s%L')}
    text ${record.to_json}
  </record>
</filter>
```

Note: as this script run on all logs make sure to use a field that is present in all the logs or add if/else logic to the ruby code inside the ${}.

### Static

To modify these values and use a hard-coded value as the value of applicationName and subsystemName modify the `fluentd-config` configmap and specifically the `coralogix.conf` key.
For example if we want all logs to have the 'my-awesome-app' as the applicationName,
To achive that we modify the 'record_transformer' filter:

```
<filter *.containers.**>
  @type record_transformer
  enable_ruby true
  auto_typecast true
  renew_record true
  <record>
    privateKey "#{ENV['PRIVATE_KEY']}"
    applicationName "my-awesome-app"
    subsystemName ${record.dig("kubernetes", "container_name")} 
    computerName ${record.dig("kubernetes", "host")}
    timestamp ${time.strftime('%s%L')}
    text ${record.to_json}
  </record>
</filter>
```

## Removal

To remove all resources created with manifest files use these commands:

```bash
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-cm.yaml -n monitoring
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-rbac.yaml -n monitoring
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-svc.yaml -n monitoring
kubectl delete -f https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/logs/fluentd/k8s-manifest/fluentd-ds.yaml -n monitoring
kubectl delete -f fluentd-env-cm.yaml -n monitoring
```

The output should be :

```bash
configmap "fluentd-prometheus-conf" deleted
configmap "fluentd-systemd-conf" deleted
configmap "fluentd-config" deleted
configmap "fluentd-main" deleted
daemonset.apps "fluentd-http" deleted
serviceaccount "fluentd-http" deleted
clusterrole.rbac.authorization.k8s.io "fluentd-http" deleted
clusterrolebinding.rbac.authorization.k8s.io "fluentd-http" deleted
servicemonitor.monitoring.coreos.com "fluentd-http" deleted
service "fluentd-http" deleted
configmap "fluentd-env" deleted
```

## Coralogix Endpoints

| Region | Logs Endpoint               |
|--------|-----------------------------|
| EU     | `ingress.coralogix.com`     |
| EU2    | `ingress.eu2.coralogix.com` |
| US     | `ingress.coralogix.us`      |
| SG     | `ingress.coralogixsg.com`   |
| IN     | `ingress.coralogix.in`      |

## Deploy to different namespace

If you wish to deploy the fluentd integration to a different namespace other than "monitoring" you'll need to change the fluentd-rbac.yaml file ClusterRoleBinding namespace accordingly.

## Disable Systemd Logs

In order to disable the systemd logs, remove the `fluentd-systemd-conf` configmap:

```yaml
kubectl delete cm fluentd-systemd-conf -n monitoring
```

## Dashboard

Under the `dashboard` directory, there is a Fluentd Grafana dashboard that Coralogix supplies.
In order to import the dashboard into Grafana, firstly copy the json file content.
Afterwards go to Grafana press the `Create` tab, then press `import`, and paste the copied json file.

## Coralogix Fluentd Buffer Alert

In order to create an alert on Fluentd buffer in Coralogix, please see [coralogix-alert doc](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluentd/docs/coralogix-alerts.md)
