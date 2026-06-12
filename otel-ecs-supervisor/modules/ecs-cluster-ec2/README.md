# ECS Cluster EC2 Module

Terraform module that creates an Amazon ECS cluster with an optional EC2 capacity provider. When `enable_capacity` is `true` it provisions all of the EC2 infrastructure (IAM, launch template, Auto Scaling Group, security group) and connects it to the cluster; otherwise it only creates the cluster resource itself.

## Resources
- ECS cluster with Container Insights disabled.
- Optional lookup of the latest ECS-optimized AMI via SSM.
- Optional security group allowing collector ports (`4317`, `4318`, `13133`, `8888`) from configurable CIDR blocks.
- Optional EC2 instance IAM role, instance profile, and required policy attachments.
- Optional launch template and Auto Scaling Group sized by `ecs_capacity_count`.
- Optional ECS capacity provider attached to the cluster with managed scaling settings.

## Usage

```hcl
module "ecs_cluster_ec2" {
  source = "../modules/ecs-cluster-ec2"

  name_prefix  = "otel"
  cluster_name = "otel-collector"

  enable_capacity = true
  ecs_capacity_count = 2

  vpc_id      = "vpc-0123456789abcdef0"
  subnet_ids  = ["subnet-aaa", "subnet-bbb"]
  allowed_cidr_blocks = ["10.10.0.0/16"]

  instance_type                = "t3.small"
  managed_scaling_target_capacity = 80
  managed_scaling_min_step        = 1
  managed_scaling_max_step        = 2

  tags = {
    Environment = "staging"
    Service     = "telemetry"
  }
}
```

Set `enable_capacity` to `false` if you only need the cluster and are providing capacity from another source (for example, Fargate or an existing capacity provider).

## Configuration Reference
- Review `modules/ecs-cluster-ec2/variables.tf` for the full list of inputs, defaults, and validation rules.
- Review `modules/ecs-cluster-ec2/outputs.tf` for the values exported by this module.

## Notes
- The user data simply joins the provisioned instances to the ECS cluster; add additional bootstrap logic via your own launch template if needed.
- Managed termination protection is disabled to allow Auto Scaling to replace instances without draining protection.
