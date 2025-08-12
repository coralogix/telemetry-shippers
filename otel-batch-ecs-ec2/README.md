# AWS Batch on ECS (EC2) - OpenTelemetry Collector Sidecar

You can run the OpenTelemetry Collector alongside your AWS Batch job containers by adding the collector container to your job definition. This setup enables log, metrics, and traces collection to Coralogix.

## Prerequisites

- **AWS Batch compute environment (EC2)**
- **AWS Batch job queue associated with a compute environment**

## Create SSM Parameter Store

Before proceeding, create an **SSM Parameter Store** entry using the predefined CloudFormation template [`otel_config_parameter_store_cfn.yaml`](./otel_config_parameter_store_cfn.yaml).
This template will also create a **custom ECS Task Execution role** with permissions to access this parameter store.

**If you choose to use your own role**, update it as needed and ensure it has the correct permissions to read from the SSM Parameter Store.

---

## Create the Job Definition

You can create the job definition using **AWS Console UI** or **AWS CLI**.

> **Note:** CloudFormation does not support required fields for defining multi-container AWS Batch ECS jobs. This means we **cannot** fully automate this job definition creation in CloudFormation. Instead, we must **register** it directly via the AWS CLI. Instructions below.

### **AWS Console UI**

1. Log in to your AWS Web Console and navigate to AWS Batch
2. Click on **Job Definitions** → **Create**
3. Configure the job definition:
   - Select **EC2** as the orchestration type.
   - Unselect **Use legacy containerProperties structure** option.
   - Enter a **Job Definition Name** (e.g., `my-app-with-otel`)
   - Select appropriate execution IAM role
   - Configure container settings ⬇️

### First Container (OpenTelemetry Collector)

1. Basic Configuration:
   - **Container name**: Enter `otel-collector`
   - **Image**: Enter `coralogixrepo/coralogix-otel-collector:v0.5.0`
   - **Essential**: Set to `false`
2. Configure CPU and Memory resource requirements based on your needs.
3. In Command configuration add `["--config","env:OTEL_CONFIG"]`
4. Environment Variables:
   - Add variable:
     - **Key**: `CX_APPLICATION_NAME`
     - **Value**: Enter your application name
   - Add variable:
     - **Key**: `CX_DOMAIN`
     - **Value**: Enter your Coralogix domain (e.g., `eu1.coralogix.com`)
   - Add variable:
     - **Key**: `CX_PRIVATE_KEY`
     - **Value**: Enter Coralogix API key
5. FireLens Configuration:
   - **Type**: Select `fluentbit`
6. Secrets:
   - Add secret:
     - **Key**: `OTEL_CONFIG`
     - **Value**: Enter your SSM Parameter Store ARN (e.g., `arn:aws:ssm:region:account:parameter/otel/config`)

### Second Container (Your Application)

1. Basic Configuration:
   - **Container name**: Enter your application name
   - **Image**: Your application container image
   - **Essential**: Set to `true`
2. Log Configuration:
   - Set **Log Driver** to `awsfirelens`
   - Under **Options**, add:
     - **Key**: `Name`
     - **Value**: `OpenTelemetry`
3. Dependencies:
   - Add dependency on the `otel-collector` container with condition `START`
   - This ensures the OpenTelemetry collector is running before your application starts
4. Add the necessary ENV variables for your container. E.g OTEL endpoint `otel-collector:4317`

**Review your configuration and create the job definition.**

### AWS CLI

The following JSON file defines an AWS Batch job using **ECS orchestration** with a sidecar container for OpenTelemetry Collector.

[batch-job-definition.json](./batch-job-definition.json)

It is generic and reusable so please update the placeholders and **application container** as needed.

```bash
aws batch register-job-definition --cli-input-json file://batch-job-definition.json
```

## Submit the AWS Batch Job

1. Navigate to AWS Batch → Jobs
2. Click **Submit new job**
3. Configure:
   - Enter **Job name**
   - Select your job definition revision
   - Choose your job queue
   - Set any container overrides if needed
4. Click **Submit and wait for the Job status `Running`**

## Troubleshooting

**1. Job Stuck in RUNNABLE State**

Check Compute Environment Resources. Common solutions:

- Increase max vCPUs
- Switch to `optimal` instance types
1. **Permission Issues**

   Verify Task Execution Role Access

   - Secrets Manager: Check access to Coralogix API key
   - SSM Parameter Store: Verify access to OTEL config
   - ECR: Ensure access to pull container images
