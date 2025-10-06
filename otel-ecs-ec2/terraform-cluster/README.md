# Terraform Cluster Module

## Overview
This module stands up an EC2-backed Amazon ECS cluster in the default VPC. It creates the ECS cluster resource, launch template, autoscaling group, instance IAM roles/profiles, and security groups required to run container workloads on managed EC2 instances.

## Configuration
Edit the local `Makefile` to align the deployment with your environment. Key knobs exposed there include:
- `AWS_PROFILE` and `AWS_REGION` for selecting the AWS account and region
- `CLUSTER_NAME` for naming the ECS cluster and related resources
- `INSTANCE_TYPE`, `DESIRED_CAPACITY`, `MIN_SIZE`, and `MAX_SIZE` to control the autoscaling group capacity

Once configured, use Makefile targets such as `make plan-example`, `make apply`, and `make destroy` to manage the lifecycle. For additional, less common inputs check `variables.tf`.
