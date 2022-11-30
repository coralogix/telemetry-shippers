# Coralogix Open Source Integrations
Coralogix Open Source Integrations repository is Coralogix's way to ship our best practices when it comes to interaction with our platform, as well as collaborating with our users.
Currently we support:  
Logging integrations, [Fluentd](https://www.fluentd.org/) and [Fluentbit](https://fluentbit.io/),  
Metrics integrations, [Prometheus](https://prometheus.io/),  
Tracing integrations, [OpenTelemetry](https://opentelemetry.io/)
Please see [#Getting Started](README.md#getting-started) for more information about the existing integrations.  


## Getting Started
This repository contains directories for each integration type, logs and metrics, and open-telemetry that can send all.
Inside the 'logs' integrations there are two supported `helm charts`, one using the `Coralogix` output plugin,
and another one using the `http` output plugin.
We recommend using the `http` chart, since it's an open source plugin, and therefore it is more community driven.       
Under each integration there is an 'image' directory which our GitHub Actions workflows use in order to build the image and publish it to DockerHub. 


## Installation
Our Helm charts repository can be added to the local repos list with the following command:
it will create a repository name `coralogix-charts-virtual` if you wish to change it to anything else.
be sure to adapt you commands in the other segments reffering to this repository.
```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated helm charts from the added repository, please run: 
```bash
helm repo update
```

For installation of each integration, please go inside each intergation's directory:
- [Fluentd-HTTP chart](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluentd/http/README.md)
- [Fluent-bit-HTTP chart](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluent-bit/http/README.md)
- [OpenTelementry-Agent chart](https://github.com/coralogix/telemetry-shippers/blob/repo-redesign/otel-agent/README.md)

---
**NOTE**

All integrations require a `secret` called `integrations-privatekey` with the relevant `private key` under a secrey key called `PRIVATE_KEY`,
inside the `same namespace` that the chart is installed in.

* The `private key` appears under 'Data Flow' --> 'API Keys' in Coralogix UI:

```bash
kubectl create secret generic integrations-privatekey \
  -n <the-namespace-of-the-release> \
  --from-literal=PRIVATE_KEY=<private-key>
```

The created secret should look like this:
```yaml
apiVersion: v1
data:
  PRIVATE_KEY: <encrypted-private-key>
kind: Secret
metadata:
  name: integrations-privatekey
  namespace: <the-release-namespace>
type: Opaque 
```

---

## These integrations were checked on Kubernetes 1.20+. 
