SHELL := /bin/bash

TF ?= terraform
AWS_PROFILE ?= ""
AWS_REGION ?= eu-west-1
CLUSTER ?= ""
DESIRED ?= 1
RATE ?= 50
DURATION ?= 120s

TFVARS ?= \
  -var="ecs_cluster_name=$(CLUSTER)" \
  -var="aws_region=$(AWS_REGION)" \
  -var="desired_count=$(DESIRED)" \
  -var="rate_per_second=$(RATE)" \
  -var="duration=$(DURATION)"

.PHONY: init validate plan fmt apply destroy stop

init:
	$(TF) init -backend=false

validate:
	$(TF) validate

fmt:
	$(TF) fmt -recursive

plan: init validate
	$(TF) plan $(TFVARS)

apply: init validate
	AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) apply -auto-approve -no-color $(TFVARS)

destroy: init validate
	AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) destroy -auto-approve -no-color $(TFVARS)

# Scale to zero without destroying resources
stop: init validate
	AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) apply -auto-approve -no-color \
	  -var="ecs_cluster_name=$(CLUSTER)" -var="aws_region=$(AWS_REGION)" -var="desired_count=0"
