# Coralogix Open Source Integrations
Coralogix Open Source Integrations repository is Coralogix's way to ship our best practices when it comes to interaction with our platform, as well as collaborating with our users.
Currently we support:  
Logging integrations, [Fluentd](https://www.fluentd.org/) and [Fluentbit](https://fluentbit.io/),  
Metrics integrations, [Prometheus](https://prometheus.io/),  
Tracing integrations, [OpenTelemetry](https://opentelemetry.io/).  

Please see [#Getting Started](README.md#getting-started) for more information about the existing integrations.  


## Getting Started
This repository contains directories for each integration type, logs and metrics, and open-telemetry that can send all.  
Inside each integration type there are multiple ways to install our integrations, using helm, installing kubernetes manifests directly, using a docker image or installing a service.

## Helm/Kubernetes integrations prerequisite

All K8s integrations, both helm and manifests, require a `secret` called `coralogix-keys` with the relevant `private key` under a secret key called `PRIVATE_KEY`,
inside the `same namespace` that the integration is installed in.

* The `private key` appears under 'Data Flow' --> 'API Keys' in Coralogix UI:

```bash
kubectl create secret generic coralogix-keys \
  -n <the-namespace-of-the-integrations> \
  --from-literal=PRIVATE_KEY=<private-key>
```

for more information regarding the coralogix private key please visit [here](https://coralogix.com/docs/private-key/)

The created secret should look like this:
```yaml
apiVersion: v1
data:
  PRIVATE_KEY: <encrypted-private-key>
kind: Secret
metadata:
  name: coralogix-keys
  namespace: <the-integration-namespace>
type: Opaque 
```
## Installation

### Helm
In the 'logs' integrations inside the 'k8s-helm' there are two supported `helm charts`, one using the `Coralogix` output plugin,
and another one using the `http` output plugin.
We recommend using the `http` chart, since it's an open source plugin, and therefore it is more community driven.       
Under each integration there is an 'image' directory which our GitHub Actions workflows use in order to build the image and publish it to DockerHub. 

Our Helm charts repository can be added to the local repos list with the following command:
it will create a repository name `coralogix-charts-virtual` if you wish to change it to anything else.
be sure to adapt your commands in the other segments referring to this repository.
```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated helm charts from the added repository, please run: 
```bash
helm repo update
```

For installation of each integration, please go inside each intergation's directory:
- [Fluentd-HTTP chart](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluentd/k8s-helm/http/README.md)
- [Fluent-bit-HTTP chart](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluent-bit/k8s-helm/http/README.md)
- [Prometheus operator chart](https://github.com/coralogix/telemetry-shippers/blob/master/metrics/prometheus/operator/README.md)
- [OpenTelementry-Agent chart](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/README.md)


### Kubernetes

Our k8s manifests integration allow you to install without the use of Helm, specifically for those times were using helm is impossible.

For installation of each integration, please go inside each intergation's directory:
- [Fluentd-HTTP](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluentd/k8s-manifest/http/README.md)
- [Fluent-bit-HTTP](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluent-bit/k8s-maifest/http/README.md)

## These integrations were checked on Kubernetes 1.20+. 
