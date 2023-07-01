.PHONY: builder
build:
	go install -v go.opentelemetry.io/collector/cmd/builder@latest
	builder --config ./builder.yaml

# .PHONY: clean
clean:
	rm -rf ./cmd


