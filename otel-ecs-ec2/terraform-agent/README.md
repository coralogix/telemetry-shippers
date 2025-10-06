# Terraform Agent Module

## Overview
This module deploys the Coralogix OpenTelemetry agent as a daemon-style ECS service on an existing EC2-backed ECS cluster. It provisions the task definition, service, and supporting CloudWatch log group needed to run the collector across every container instance.

## Configuration
All common configuration variables are surfaced in the local `Makefile`. Update the Makefile before running commands to point to your AWS account and cluster, and to set runtime parameters like:
- `CLUSTER`, `AWS_REGION`, and `AWS_PROFILE` to target the correct environment
- `memory`, `image`, and API key related settings passed through the example TF variables block

After adjusting the values, use the Makefile targets such as `make plan-example`, `make apply`, or `make destroy` to manage the deployment. Review `variables.tf` for the full list of optional inputs supported by the module.
