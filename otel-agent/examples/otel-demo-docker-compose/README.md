# OpenTelemetry Demo

This demo shows how the OpenTelemtry collector sends data to Coralogix. The stack here serves
a robust online store with an automatic traffic generator. The signals data will be sent to Coralogix backend.

The setup is based on [otel-demo](https://github.com/open-telemetry/opentelemetry-demo/tree/v0.3.1-alpha), which contains services exposing tracing telemetry data from all running platforms:
* Java
* Rust
* GoLang
* Ruby
* .NET
* C++
* Python
* JavaScript
* Erlang/Elixir

All the examples are using `open-telemtry` SDK. Which can be found [here](https://opentelemetry.io/docs/instrumentation/)

The source code for this demo is available [here](https://github.com/open-telemetry/opentelemetry-demo/tree/v0.3.1-alpha) under the `/src` directory. 

## Before you begin

1. Install the Docker client on your machine. This demo runs in Docker.
2. [Sign up](https://dashboard.eu2.coralogix.com/#/signup) for a Coralogix account, if you don't have one yet. 
3. Visit `https://YOUR_ACCOUNT_NAME.app.coralogix.us/#/integration/apikey` (updating `YOUR_ACCOUNT_NAME`
   with the name of the account you have created during the signup. This is where you can access your API key. 
   Keep this page around for one moment.

## Installation
=======
The source code for this demo is available [here](https://github.com/open-telemetry/opentelemetry-demo/tree/v0.3.1-alpha) under the `/src` directory.

## Installation

In order to ship traffic to your Coralogix account, please edit `otelcol-config.yml` and upadte the following:
* ENDPOINT
* PRIVATE_KEY

Getting started is easy! 

1. Open the [otelcol-config.yml](https://github.com/coralogix/telemetry-shippers/blob/master/otel-agent/examples/otel-demo-docker-compose/otelcol-config.yml)
   file in this directory and update the two Coralogix fields at the top of the page.
   * The `CORALOGIX_ENDPOINT` should be set to appropriate endpoints accepting data. Please see [our documentation](https://coralogix.com/docs/coralogix-endpoints/) to know which endpoint to use. 
   * The `CORALOGIX_API_KEY` should come from the integration link indicated above. Use the "Send Your Data"
     access key.
2. Run `docker compose up -d`
3. In your Coralogix UI, visit the "Explore" tab and click on "Tracing". You should see some input.
   * If you do not, check out `docker logs otel-col` and look for any issues. It should look like this
   on the latest line of the log:
```
2023-05-01T22:39:28.349Z	info	service/service.go:157	Everything is ready. Begin running and processing data.
```
4. Visit `http://localhost:8089` and try increasing the volume of traffic to increase the output to Coralogix.

## Suggested reading

* https://coralogix.com/docs/guide-first-steps-coralogix/
* https://opentelemetry.io/docs/what-is-opentelemetry/
* https://opentelemetry.io/docs/collector/configuration/
=======
## Coralogix Endpoints

Please Check https://coralogix.com/docs/coralogix-endpoints/.
