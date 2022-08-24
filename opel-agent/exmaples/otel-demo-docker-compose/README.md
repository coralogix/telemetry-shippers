# OpenTelemetry Demo
This Online Boutique with exmaple how to confiugre the open-telemetry collector to send data to Coralogix.
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



## Installation
In order to ship traffic to your Coralogix account, please edit `otelcol-config.yml` and upadte the following:
* ENDPOINT
* PRIVATE-KEY

```bash
docker-compose up -d 
```

## Coralogix Endpoints

| Region  | Traces Endpoint
|---------|------------------------------------------|
| USA1	  | `tracing-ingress.coralogix.us`           |
| APAC1   | `tracing-ingress.app.coralogix.in`       |
| APAC2   | `tracing-ingress.coralogixsg.com`        |
| EUROPE1 | `tracing-ingress.coralogix.com`          |
| EUROPE2 | `tracing-ingress.eu2.coralogix.com`      |

