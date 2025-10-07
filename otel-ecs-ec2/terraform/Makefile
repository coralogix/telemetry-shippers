SHELL := /bin/bash

AWS_PROFILE ?= ""
AWS_REGION ?= ""
CLUSTER_NAME ?= ""
API_KEY ?= ""
TF ?= terraform
INSTANCE_TYPE ?= t3.micro
DESIRED_CAPACITY ?= 1
MIN_SIZE ?= 1
MAX_SIZE ?= 2
AGENT_MEMORY ?= 256
TELEMETRYGEN_DESIRED_COUNT ?= 1
TELEMETRYGEN_RATE ?= 50
TELEMETRYGEN_DURATION ?= 120s

TFVARS_EXAMPLE ?= \
  -var="cluster_name=$(CLUSTER_NAME)" \
  -var="aws_region=$(AWS_REGION)" \
  -var="instance_type=$(INSTANCE_TYPE)" \
  -var="desired_capacity=$(DESIRED_CAPACITY)" \
  -var="min_size=$(MIN_SIZE)" \
  -var="max_size=$(MAX_SIZE)" \
  -var="memory=$(AGENT_MEMORY)" \
  -var="api_key=$(API_KEY)" \
  -var="desired_count=$(TELEMETRYGEN_DESIRED_COUNT)" \
  -var="rate_per_second=$(TELEMETRYGEN_RATE)" \
  -var="duration=$(TELEMETRYGEN_DURATION)"

.PHONY: init validate plan-example fmt apply destroy stop redeploy

init:
	$(TF) init -backend=false

validate:
	$(TF) validate

fmt:
	$(TF) fmt -recursive

plan-example: init validate
	$(TF) plan $(TFVARS_EXAMPLE)

apply: init validate
	AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) apply -auto-approve -no-color $(TFVARS_EXAMPLE)

destroy: init validate
	AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) destroy -auto-approve -no-color $(TFVARS_EXAMPLE)

stop: init validate
	AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) apply -auto-approve -no-color \
	  -var="cluster_name=$(CLUSTER_NAME)" -var="aws_region=$(AWS_REGION)" -var="desired_count=0"

redeploy: destroy apply
