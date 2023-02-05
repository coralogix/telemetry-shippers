# ECS - OpenTelemetry
This Image is built from the __Otel-contrib 0.62.0__ image.

The image configuration utilises the _otlp receiver_ for both _HTTP (on 4318)_  and _GRPC (on 4317)_. Data can be sent using either endpoint.

Our Coralogix exporter allows us to use enrichments such as dynamic `application` or `subsystem` name, which is defined using: `application_name_attributes` and `subsystem_name_attributes` respectively. See [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) for more information on the Coralogix Exporter.


This guide shows the process for deploying Open Telemetry to ECS to fascilitate the collection of logs, metrics and traces.

### Required

- [AWS credentials must be configured](https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/setup-credentials.html)
- [ecs-cli](https://github.com/aws/amazon-ecs-cli#installing)
- [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### Getting Started

Clone the telemetry-shippers repo and `cd` to `otel-agent/ECS`

```
git clone https://github.com/coralogix/telemetry-shippers.git
cd telemetry-shippers/otel-agent/ECS/
```


### Open Telemetry Configuration

Configuration is handled by copying the OTel configuration file into a container image. This image is then used to build an ECS Task Definition and Service. For the purpose of this guide you do not need to build a custom configuration and image, as one is provided by default. However, you can supply your own otel image with configuration embedded if needed.

Images stored in AWS ECR can also be accessed by ECS directly.



To push an image to ECR

```sh
ecs-cli push --region <region> image:tag
```

A repository will be created automatically if one does not already exist.



### ECS Cluster

If you already have an existing ECS Cluster you can skip this step. 

__Deploy a new cluster:__

```sh
ecs-cli up --region <region> --keypair <your-key-pair> --cluster <cluster-name> --size <no. of instances> --capability-iam 
```

The `--keypair` flag is not mandetory, however, if not supplied you will not be able to connect to any of the instances in the cluster via SSH. You can create a key pair using the command below:

```sh
aws ec2 create-key-pair --key-name MyKeyPair --query 'KeyMaterial' --output text > MyKeyPair.pem
```

The `ecs-cli up` command will levarage cloudformation to create an ECS Cluster. Default values will be used to create and configure a VPC and Subnets, however these values and more can be controlled from `ecs-cli` as well, see:

```sh
ecs-cli up --help
```


### ECS Task Definition & Service

Once we have an ECS Cluster in place, we need to deploy a Task Definition, which is used by ECS to create an ECS Service to run Open Telemetry.

A __Task Definition__ is a template defining a container configuration and an __ECS Service__ is a configuration item that defines and orchestrates how a task definition should be run.


We can deploy these resources by using the cloudform template defined [here](./cfn_template.yaml). This template has a number of parameters outlined below:

| Parameter | Description | Default Value | Required |
|---|---|---|---|
| ClusterName | The name of an __existing__ ECS Cluster |   | :heavy_check_mark: | 
| Image | The open telemtry collector container image.<br><br>ECR Images must be prefixed with the ECR image URI. For eg. `<AccountID>.dkr.ecr.<REGION>.amazonaws.com/image:tag` | coralogixrepo/otel-coralogix-ecs | |
| Memory | The amount of memory to allocate to the Open Telemetry container.<br>_Assigning too much memory can lead to instances not being deployed. Make sure that values are within the range of what is available on your ECS Cluster_ | 256 | |
| CoralogixRegion | The region of your Coralogix Account | _Allowed Values:_<br>- Europe<br>- Europe2<br>- India<br>- Singapore<br>- US | :heavy_check_mark: |
| ApplicationName | You application name |  | :heavy_check_mark: |
| SubsystemName | You Subsystem name | AWS Account ID | __Required__ when using the default Coralogix image. |
| PrivateKey | Your Coralogix Private Key | | __Required__ when using the default Coralogix image. |


__Deploy the Cloudformation template__:

```sh
aws cloudformation deploy --template-file cfn_template.yaml --stack-name cds-68 \
    --region <region> \
    --parameter-overrides \
        ApplicationName=<application name> \
        ClusterName=<ecs cluster name> \
        PrivateKey=<your-private-key> \
        CoralogixRegion=<coralogix-region>
```

Once the template is deployed successfully, you can verify if the container is running using:

```sh
ecs-cli ps --region <region> -c <cluster name>
```