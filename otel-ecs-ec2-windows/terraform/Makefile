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
  -var="api_key=$(API_KEY)"

.PHONY: init validate plan-example fmt apply destroy redeploy output

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
