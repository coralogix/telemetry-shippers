TOOLS_BIN_DIR ?= $(shell pwd)/tmp/bin
export PATH := $(TOOLS_BIN_DIR):$(PATH)

MDOX_BINARY=$(TOOLS_BIN_DIR)/mdox
TOOLING=$(MDOX_BINARY)

$(TOOLS_BIN_DIR):
	mkdir -p $(TOOLS_BIN_DIR)

$(TOOLING): $(TOOLS_BIN_DIR)
	@echo Installing tools from .github/tools/tools.go
	@cat .github/tools/tools.go | grep _ | awk -F'"' '{print $$2}' | GOBIN=$(TOOLS_BIN_DIR) xargs -tI % go install -mod=readonly -modfile=.github/tools/go.mod %


.PHONY: check-docs
check-docs: $(MDOX_BINARY)
	@echo ">> formatting and local/remote link check"
	find . -regex ".*.md" | xargs $(MDOX_BINARY) fmt --links.validate.config-file .mdox.validate.yaml -l --check --soft-wraps

.PHONY: fmt-docs
fmt-docs: $(MDOX_BINARY)
	@echo ">> formatting and local/remote link check"
	find . -regex ".*.md" | xargs $(MDOX_BINARY) fmt --links.validate.config-file .mdox.validate.yaml -l --soft-wraps