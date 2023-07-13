FROM golang:1.19-alpine as builder

ADD ./ecsattributesprocessor /go/src/ecsattributesprocessor
RUN  go install go.opentelemetry.io/collector/cmd/builder@latest

WORKDIR /go/src/ecsattributesprocessor

RUN apk update && apk add --no-cache gcc musl-dev linux-headers

RUN go test

RUN builder --config builder.yaml

FROM alpine:latest

RUN apk update && apk add --no-cache ca-certificates

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh

COPY --from=builder /go/src/ecsattributesprocessor/cmd/cora-otel-ecs-ec2 /cora-otel-ecs-ec2
EXPOSE 4318 4317 55679

ENTRYPOINT [ "/entrypoint.sh" ]
