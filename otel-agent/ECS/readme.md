ECS - OpenTelemetry
Image is built upon the Otel-contrib 0.70.0.
This image currently supports otlp reciver, that's why we're exposing port 4318. Therefore your application needs to send the data to the said port.
By using our Coralogix exporter it allows us to use enrichments such as dynamic application/subsystem name, this is defined in this key: "application_name_attributes"/ "subsystem_name_attributes"
In ECS it's going to be defiend as such: OTEL_RESOURCE_ATTRIBUTES APP_NAME=Test,SUB_SYS=example
Private_key and Traces are also ENV var which allow us to define the Coralogix private key and the correct Coralogix Endpoint.