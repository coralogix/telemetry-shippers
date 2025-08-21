# Minimal Makefile for ecs-ec2 module

TF ?= terraform
TFVARS_EXAMPLE ?= \
  -var="ecs_cluster_name=ecs-ec2-example-cluster" \
  -var="image_version=v0.4.0" \
  -var="memory=256" \
  -var="api_key=cxtp_example_key_replace_me"

.PHONY: init validate plan-example fmt

init:
	$(TF) init -backend=false

validate:
	$(TF) validate

fmt:
	$(TF) fmt -recursive

plan-example: init validate
	$(TF) plan $(TFVARS_EXAMPLE)
