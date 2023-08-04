*Coralogix* provides integration to collect and send your `ECS` cluster logs straight to *Coralogix*.

## General

**Private Key** – A unique ID representing your company, this ID will be sent to your email once you sign up to *Coralogix* and can also be found under settings > send your logs.

**Application Name** – The name of your main application, for example, a company named *“SuperData”* would probably insert the *“SuperData”* string parameter or if they want to debug their test environment they might insert the *“SuperData– Test”*.

**SubSystem Name** – Your application probably has multiple subsystems, for example Backend servers, Middleware, Frontend servers, etc. in order to help you examine the data you need, inserting the subsystem parameter is vital.

### EC2

To start sending logs from your ecs ec2 containers we need to create a new `ECS Task Definition`.

Go to the ECS console and choose ‘Task Definitions’ -> ‘Create new task definition’.

Under ’Select launch type compatibility:

- Choose ‘EC2’ and click on the next step

Scroll all the way down and click on the ‘Configure via JSON’ button.

- Paste there the [predefined](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluentd/aws-ecs/Json_TaskDefinition) file


Replace inside the file these environment variables:

- ENDPOINT- your team endpoint depending on the geo location
- log_level- the log level in which the fluend is set to (default is “info”)
- PRIVATE_KEY- your team’s private key

Run `AWS ECS Task` on your cluster:

Choose `Placement Template` as `One Task Per Host`:

When the task is ready, logs will start shipping to *Coralogix*.

### Fargate

To start sending logs from your ecs fargate containers we need to create a new `ECS Task Definition`.

Go to the ECS console and choose ‘Task Definitions’ -> ‘Create new task definition’.

Under ’Select launch type compatibility:

- Choose ‘FARGATE’ and click on the next step

Scroll down and under ‘Log router integration’:

- Tick ‘Enable FireLens integration’
- For ‘Type’ choose ‘fluentd’
- For ‘Image’ write ‘docker.io/coralogixrepo/fluentd-coralogix-ecs:1.7.0’

Configure `awsfirelens` logging driver for the container to which you want to send the logs:

- Under log configuration, the log driver must be: awsfirelens
- The @type should be: null

Click on the ‘log_router’ container to edit it:

Under ‘Environment variables’ add these variables:

- APP_NAME- your application name
- ENDPOINT- your coralogix cluster URL.
- log_level- the log level in which the fluend is set to (use ‘error’)
- PRIVATE_KEY- your team’s private key
- SUB_SYSTEM- the subsystem name that will appear in Coralogix

Save the changes to the container.

Scroll all the way down and click on the ‘Configure via JSON’ button.

Replace ‘fireLensConfiguration’ with:

```
  "firelensConfiguration": {
    "type": "fluentd",
    "options": {
      "config-file-type": "file",
      "config-file-value": "/fluentd/etc/firelens.conf"
    }
  },
```
