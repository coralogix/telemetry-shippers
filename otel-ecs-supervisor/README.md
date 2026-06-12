# OpenTelemetry ECS Supervisor - Terraform Module

This Terraform module deploys the OpenTelemetry Supervisor on AWS ECS Fargate or EC2. The supervisor enables remote configuration management through OpAMP (Open Agent Management Protocol) and provides OTLP endpoints for telemetry collection.

## Quick Start

### Using the Makefile

The module includes a `Makefile` with convenient commands for deployment and management:

```bash
# Check prerequisites (Terraform, AWS CLI, credentials)
make check-prereqs

# Initialize Terraform
make init

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Validate and plan
make test

# Deploy to test environment
make deploy-test

# Or step by step:
make plan
make apply

# Clean up when done
make destroy
```

Available make targets:

**Basic Operations:**
- `make help` - Show all available commands
- `make check-prereqs` - Verify required tools and AWS credentials
- `make init` - Initialize Terraform
- `make plan` - Generate execution plan
- `make apply` - Apply configuration
- `make destroy` - Destroy infrastructure
- `make clean` - Clean up temporary files

**Testing & Validation:**
- `make test` - Run basic validation and format checking
- `make test-templates` - Test Terraform template generation
- `make test-example` - Validate example configuration
- `make test-integration` - Run comprehensive integration tests
- `make validate-security` - Run security validation checks
- `make ci-test` - Full CI/CD test suite

**Development:**
- `make fmt` - Format Terraform files
- `make lint` - Run linting and validation
- `make deploy-test` - Deploy with auto-approval

**Deployment Verification:**
- `make deploy-and-verify` - Deploy and verify the deployment works
- `make verify-deployment` - Check service and task status
- `make check-logs` - View recent application logs
- `make health-check` - Comprehensive deployment health check

## Security

- **Least Privilege IAM**: Minimal permissions for task execution and runtime
- **Secret Management**: Support for AWS Secrets Manager and SSM Parameter Store
- **Network Security**: Configurable security groups and CIDR restrictions
- **Logging**: CloudWatch integration for audit and debugging

## Monitoring

The supervisor automatically reports to Coralogix:
- **Health status** via OpAMP
- **Configuration updates** and status
- **Collector metrics** and performance
- **Application telemetry** (logs, metrics, traces)

## ECS Cluster Options

- `create_ecs_cluster` — set to `true` to let this module provision a dedicated ECS cluster.
- `ecs_cluster_name` — optional override for the created cluster name (defaults to `name_prefix`).
- `ecs_cluster_id` — supply the ARN or name of an existing cluster when you reuse infrastructure.

## EC2 Capacity

- `ecs_capacity_count` — number of EC2 container instances to keep running when `launch_type` is `EC2` (set to `0` to skip capacity provisioning).
- Default VPC and subnets are used automatically when none are supplied, and instances run on the latest ECS-optimized Amazon Linux 2 AMI with the `t3.micro` size.

## Troubleshooting

```bash
# View task logs (replace {name_prefix} with your actual prefix)
aws logs get-log-events --log-group-name "{name_prefix}/supervisor" --log-stream-name "supervisor/supervisor/{task-id}"

# Check task definition
aws ecs describe-task-definition --task-definition "{name_prefix}-supervisor"

# View running tasks
aws ecs list-tasks --cluster "your-cluster" --service-name "{name_prefix}-supervisor"

# Check task health and status
aws ecs describe-tasks --cluster "your-cluster" --tasks "{task-arn}"

# Check SSM parameters
aws ssm get-parameter --name "/{name_prefix}/supervisor/config" --with-decryption
aws ssm get-parameter --name "/{name_prefix}/collector/config"
```
