# Changelog

## OpenTelemetry EKS-Fargate

### v0.0.6 / 2026-06-16

* [BREAKING] Rename Kubernetes secret key from `PRIVATE_KEY` to `CORALOGIX_PRIVATE_KEY` to match the container environment variable name. Before applying updated manifests, recreate the secret:
  ```bash
  kubectl delete secret coralogix-keys -n $NAMESPACE
  kubectl create secret generic coralogix-keys -n $NAMESPACE --from-literal=CORALOGIX_PRIVATE_KEY=<your-api-key>
  ```

### v0.0.5 / 2025-05-14
* [FIX] Remove overwrite of k8s.node.name attribute

### v0.0.4 / 2025-05-06
* [FEAT] Add k8sattributes proccesor

### v0.0.3 / 2024-10-21
* [FIX] Add OTLP HTTP receiver

### v0.0.2 / 2023-12-14
* [FIX] Deploy to and monitors Fargate portion of mixed ec2+fargate cluster

### v0.0.1 / 2023-08-17

* [NEW] Added EKS Fargate related configuration files
* [DOC] Documented EKS Fargate OTEL integration
