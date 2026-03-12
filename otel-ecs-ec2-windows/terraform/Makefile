SHELL := /bin/bash

AWS_PROFILE ?= ""
AWS_REGION ?= ""
CLUSTER_NAME ?= ""
API_KEY ?= ""
TF ?= terraform
INSTANCE_TYPE ?= t3.large
DESIRED_CAPACITY ?= 1
MIN_SIZE ?= 1
MAX_SIZE ?= 2
TASK_CPU ?= 1024
TASK_MEMORY ?= 2048
ECS_CONTAINER_START_TIMEOUT ?= 15m
ENABLE_TELEMETRYGEN ?= true
# Leave empty to use the ECR repository created by Terraform (push image after apply).
TELEMETRYGEN_IMAGE ?=
TELEMETRYGEN_IMAGE_TAG ?= 0.121.0-windows2022
TELEMETRYGEN_RATE ?= 10
TELEMETRYGEN_SERVICE_NAME ?= telemetrygen-windows

TFVARS_EXAMPLE ?= \
  -var="cluster_name=$(CLUSTER_NAME)" \
  -var="aws_region=$(AWS_REGION)" \
  -var="instance_type=$(INSTANCE_TYPE)" \
  -var="desired_capacity=$(DESIRED_CAPACITY)" \
  -var="min_size=$(MIN_SIZE)" \
  -var="max_size=$(MAX_SIZE)" \
  -var="task_cpu=$(TASK_CPU)" \
  -var="task_memory=$(TASK_MEMORY)" \
  -var="ecs_container_start_timeout=$(ECS_CONTAINER_START_TIMEOUT)" \
  -var="api_key=$(API_KEY)" \
  -var="enable_telemetrygen=$(ENABLE_TELEMETRYGEN)" \
  $(if $(TELEMETRYGEN_IMAGE),-var="telemetrygen_image=$(TELEMETRYGEN_IMAGE)") \
  -var="telemetrygen_image_tag=$(TELEMETRYGEN_IMAGE_TAG)" \
  -var="telemetrygen_rate=$(TELEMETRYGEN_RATE)" \
  -var="telemetrygen_service_name=$(TELEMETRYGEN_SERVICE_NAME)"

.PHONY: init validate plan-example fmt apply destroy redeploy output ecr-login

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

redeploy: destroy apply

output:
	AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) output

# Log Docker into ECR (run before pushing the telemetrygen image). Uses AWS_REGION and AWS_PROFILE.
ecr-login:
	AWS_PROFILE=$(AWS_PROFILE) aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$(AWS_PROFILE=$(AWS_PROFILE) aws sts get-caller-identity --query Account --output text).dkr.ecr.$(AWS_REGION).amazonaws.com
