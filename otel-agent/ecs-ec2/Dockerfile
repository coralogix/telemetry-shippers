FROM golang:1.19-alpine as builder

ADD ./ecslogresourcedetectionprocessor /go/src/ecslogresourcedetectionprocessor
RUN  go install go.opentelemetry.io/collector/cmd/builder@latest

WORKDIR /go/src/ecslogresourcedetectionprocessor

RUN apk update && apk add --no-cache gcc musl-dev linux-headers

RUN builder --config builder.yaml

FROM alpine:latest

RUN apk update && apk add --no-cache ca-certificates

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh

COPY --from=builder /go/src/ecslogresourcedetectionprocessor/cmd/cora-otel-ecs-ec2 /cora-otel-ecs-ec2
EXPOSE 4318 4317 55679

ENTRYPOINT [ "/entrypoint.sh" ]
