# OpenTelemetry EKS Fargate

The EKS Fargate integration is broken down into two parts, Metrics and Traces performed by OpenTelemetry, and Logs, using the AWS log_router framework. Each integration can be deployed completely independent of each other. In this document, we'll discuss Metrics and Traces via OTEL.

# Metrics and Traces

The Coralogix EKS Fargate integration for Metrics and Traces leverages OpenTelemetry Collector (Contrib) to collect pod and container metrics of your Fargate workloads. It does so by querying the Kubelet stats API running on each node. As Fargate hosts are managed by AWS, node metrics are not available.

## Requirements:

- `cx-eks-fargate-otel` namespace declared in your EKS cluster
    - This namespace need not be hosted by a Fargate profile, but if it is desired, you’ll need to create one.
- A Secret containing your Coralogix API Key, in the `cx-eks-fargate-otel` namespace.

## Creating Secret

1. Export your API key to a local variable:
    1. `export PRIVATE_KEY=<Send-Your-Data API key>`
2. Set your namespace variable:
    1. `export NAMESPACE=cx-eks-fargate-otel`
3. Create the secret using kubectl:
    1. `kubectl create secret generic coralogix-keys -n $NAMESPACE --from-literal=PRIVATE_KEY=$PRIVATE_KEY`
4. Confirm it’s been set
    1. `kubectl get secret coralogix-keys -o yaml -n $NAMESPACE`

## Create ServiceAccount

In order for the OTEL collector to get full access to the Kubernetes API, it’ll need a ServiceAccount to bind to. We can create the service account by running the following bash script. Simply set the CLUSTER_NAME and REGION accordingly, everything else should remain unchanged.

```bash
#!/bin/bash
CLUSTER_NAME=<EKS Cluster Name>
REGION=<EKS Cluster Region>
SERVICE_ACCOUNT_NAMESPACE=cx-eks-fargate-otel
SERVICE_ACCOUNT_NAME=cx-otel-collector
SERVICE_ACCOUNT_IAM_ROLE=EKS-Fargate-cx-OTEL-ServiceAccount-Role
SERVICE_ACCOUNT_IAM_POLICY=arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

eksctl utils associate-iam-oidc-provider \
--cluster=$CLUSTER_NAME \
--approve

eksctl create iamserviceaccount \
--cluster=$CLUSTER_NAME \
--region=$REGION \
--name=$SERVICE_ACCOUNT_NAME \
--namespace=$SERVICE_ACCOUNT_NAMESPACE \
--role-name=$SERVICE_ACCOUNT_IAM_ROLE \
--attach-policy-arn=$SERVICE_ACCOUNT_IAM_POLICY \
--approve
```

## Configure and Deploy OTEL Collector Service:

The attached yaml manifest will deploy an OTEL collector, a clusterIP service for submission of application traces and metrics, and the cluster permissions required to query the Kubernetes API. 

There are a few container environment variables that need to be set, detailed at the top of the yaml file.

[cx-eks-fargate-otel.yaml](./cx-eks-fargate-otel.yaml)

Once you’ve adjusted the manifests appropriately, deploy using the kubectl apply command:

`kubectl apply -f cx-eks-fargate-otel.yaml`

This manifest is all that is required to collect metrics from your EKS Fargate Cluster and process application metrics and traces from gRPC sources. The OTLP gRPC endpoint is:

`http://cx-otel-collector-service.cx-eks-fargate-otel.svc.cluster.local:4317`

## Configure and Deploy Self Monitoring Pod:

Since Fargate workloads are unable to directly communicate with their host due to networking restrictions, we cannot monitor the OTEL collector pod’s performance directly. Instead, we have constructed a secondary Manifest that’ll deploy a second OTEL collector to collect just these missing pod metrics.

This manifest also has some required environmental variables that need to be set, detailed at the top:

[cx-eks-fargate-otel-self-monitoring.yaml](./cx-eks-fargate-otel-self-monitoring.yaml)

Again, after setting the environment variables, deploy using kubectl apply:

`kubectl apply -f cx-eks-fargate-otel-self-monitoring.yaml`