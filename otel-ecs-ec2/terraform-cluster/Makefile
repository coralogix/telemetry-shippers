# Minimal Makefile for ecs cluster module

TF ?= terraform
AWS_PROFILE ?= ""
AWS_REGION ?= eu-west-1
# Please customize the cluster name to avoid conflicts with existing clusters
CLUSTER_NAME ?= ""
INSTANCE_TYPE ?= t3.micro
DESIRED_CAPACITY ?= 1
MIN_SIZE ?= 1
MAX_SIZE ?= 2
TFVARS_EXAMPLE ?= \
  -var="cluster_name=$(CLUSTER_NAME)" \
  -var="region=$(AWS_REGION)" \
  -var="instance_type=$(INSTANCE_TYPE)" \
  -var="desired_capacity=$(DESIRED_CAPACITY)" \
  -var="min_size=$(MIN_SIZE)" \
  -var="max_size=$(MAX_SIZE)"

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
