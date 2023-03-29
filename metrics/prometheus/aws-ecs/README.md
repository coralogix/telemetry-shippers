## ECS prometheus node exporter

Prometheus is an open-source monitoring solution for collecting and aggregating metrics as time series data.  
Using this ECS task definition will install on your ECS cluster a node exporter which exports the host metrics
and promethues which will send these metrics to your coralogix account.

### Installation 

Task Creation:
- Create a new ECS Task definition
- Scroll all the way down and click on 'Configure via JSON'
- Copy taskdefinition.json and paste
- Modify the environment variables ['CORALOGIX_ENDPOINT', 'CORALOGIX_PRIVATEKEY', 'SCRAPE_INTERVAL'] inside the prometheus container

Service run:
- Choose launchtype 'ec2'
- Choose task family 'coralogix-ecs-prometheus'
- Under Service type pick 'Daemon'
- Complete other settings as you choose, no need for load balancer.

### Variables

CORALOGIX_ENDPOINT - your coralogix endpoint according to your account cluster, Check https://coralogix.com/docs/coralogix-endpoints/.  
CORALOGIX_PRIVATEKEY - your coralogix private 'send your data' key.  
SCRAPE_INTERVAL - the interval between each scrape of data, default to 1m (1 minute).  



### Todo

- Add prometheus as a deployment and not daemon set by using ec2_sd_configs.
