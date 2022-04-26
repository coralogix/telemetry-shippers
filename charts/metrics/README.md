# Metrics 
Metrics is a Coralogix feature which allows shipping metrics to Coralogix with Prometheus' Remote Write API. 

The components included in this repo provide this integration of Prometheus with Coralogix, including multiple options:
* Prometheus chart for installing Prometheus with Coralogix's best practices,
  including the remote write configuration for shipping the metrics to Coralogix. 
* Prometheus agent for shipping metrics to Coralogix from Prometheus, without having a Prometheus to manage. 


## Components included in the Metrics integration:
* The Prometheus Operator
* Highly available Prometheus






1. What is the motivation
3. How to use
#4. How to use custom metrics - instruct users on serviceMonitors definition - not yet
5. How to debug not shipped metrics to Coralogix - dashboard prometheus - troubleshooting  - like servicedescovery , scraping high, target unreachable, wrong servicemonitor 
6. Explain on external_labels - how and why to send us external labels 



components
remote write - why how configure optimization
exporters

logging
metrics
