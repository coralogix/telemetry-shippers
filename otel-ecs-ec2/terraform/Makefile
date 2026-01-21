SHELL := /bin/bash

AWS_PROFILE ?= ""
AWS_REGION ?= ""
CLUSTER_NAME ?= ""
API_KEY ?= ""
CDOT_IMAGE ?= coralogixrepo/coralogix-otel-collector:v0.5.7
ECS_AMI_SSM_PARAMETER ?=
TF ?= terraform
INSTANCE_TYPE ?= t3.micro
DESIRED_CAPACITY ?= 1
MIN_SIZE ?= 1
MAX_SIZE ?= 2
AGENT_MEMORY ?= 256
TELEMETRYGEN_DESIRED_COUNT ?= 1
TELEMETRYGEN_RATE ?= 50
TELEMETRYGEN_DURATION ?= 120s

ifeq ($(strip $(CDOT_IMAGE)),)
  CDOT_IMAGE_REPO :=
  CDOT_IMAGE_TAG :=
else
  CDOT_IMAGE_REPO := $(word 1,$(subst :, ,$(CDOT_IMAGE)))
  CDOT_IMAGE_TAG := $(word 2,$(subst :, ,$(CDOT_IMAGE)))
endif

TFVARS_EXAMPLE ?= \
  -var="cluster_name=$(CLUSTER_NAME)" \
  -var="aws_region=$(AWS_REGION)" \
  -var="instance_type=$(INSTANCE_TYPE)" \
  -var="desired_capacity=$(DESIRED_CAPACITY)" \
  -var="min_size=$(MIN_SIZE)" \
  -var="max_size=$(MAX_SIZE)" \
  -var="memory=$(AGENT_MEMORY)" \
  -var="api_key=$(API_KEY)" \
  $(if $(ECS_AMI_SSM_PARAMETER),-var="ecs_ami_ssm_parameter=$(ECS_AMI_SSM_PARAMETER)") \
  -var="desired_count=$(TELEMETRYGEN_DESIRED_COUNT)" \
  -var="rate_per_second=$(TELEMETRYGEN_RATE)" \
  -var="duration=$(TELEMETRYGEN_DURATION)" \
  $(if $(CDOT_IMAGE_REPO),-var="image=$(CDOT_IMAGE_REPO)") \
  $(if $(CDOT_IMAGE_TAG),-var="image_version=$(CDOT_IMAGE_TAG)")

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
