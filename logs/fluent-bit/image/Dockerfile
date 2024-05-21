FROM golang:1.17.5-stretch AS builder
ARG TARGETARCH
RUN apt install gcc libc-dev git
WORKDIR /go/src/app
RUN wget -q https://raw.githubusercontent.com/fluent/fluent-bit/master/conf/plugins.conf && \
    echo "    Path /fluent-bit/plugins/out_coralogix.$TARGETARCH.so" | tee -a plugins.conf
COPY ./out_coralogix.go ./go.mod ./go.sum ./
RUN go mod vendor && \
    go build -buildmode=c-shared -ldflags "-s -w" -mod=vendor -o out_coralogix.$TARGETARCH.so .

FROM fluent/fluent-bit:3.0.4
ARG TARGETARCH
MAINTAINER Coralogix Inc. <info@coralogix.com>
LABEL Description="Special Fluent-Bit image for Coralogix integration" Vendor="Coralogix Inc." Version="3.0.4"
COPY --from=builder /go/src/app/plugins.conf /fluent-bit/etc/
COPY --from=builder /go/src/app/out_coralogix.$TARGETARCH.so /fluent-bit/plugins/out_coralogix.so
COPY ./functions.lua /fluent-bit/etc/
