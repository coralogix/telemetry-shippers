# Minimal Makefile for ecs-ec2 module

TF ?= terraform
AWS_PROFILE ?= research
AWS_REGION ?= eu-west-1
CLUSTER ?= ""
API_KEY ?= cxtp_example_key_replace_me
TFVARS_EXAMPLE ?= \
  -var="ecs_cluster_name=$(CLUSTER)" \
  -var="memory=256" \
  -var="aws_region=$(AWS_REGION)" \
  -var="api_key=$(API_KEY)"

.PHONY: init validate plan-example fmt apply destroy redeploy

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