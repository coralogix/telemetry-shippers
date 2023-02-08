# ECS - OpenTelemetry
This Image is built from the __Otel-contrib 0.70.0__ image.

The image configuration utilises the _otlp receiver_ for both _HTTP (on 4318)_  and _GRPC (on 4317)_. Data can be sent using either endpoint.

Our Coralogix exporter allows us to use enrichments such as dynamic `application` or `subsystem` name, which is defined using: `application_name_attributes` and `subsystem_name_attributes` respectively. See [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) for more information on the Coralogix Exporter.


