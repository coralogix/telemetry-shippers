## ECS prometheus node exporter

Prometheus is an open-source monitoring solution for collecting and aggregating metrics as time series data.
Using this ECS task definition will install on your ECS cluster a node exporter which exports the host metrics
and promethues which will send these metrics to your coralogix account.

### Installation 
Task Creation:
- Create a new ECS Task definition
- Scroll all the way down and click on 'Configure via JSON'
- Copy taskdefinition.json and paste
- Modify the environment variables ['CORALOGIX_ENDPOINT', 'CORALOGIX_PRIVATEKEY'] inside the prometheus container

Task run:
- Choose launchtype 'ec2'
- Choose famili 'prometheus-node-exporter'
- Under Task placement pick 'One task per host'

