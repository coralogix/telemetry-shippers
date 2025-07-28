# Makefile for managing EKS test clusters
# Prerequisites: eksctl, kubectl, aws CLI configured

.PHONY: help create-ipv6 create-windows clean-ipv6 clean-windows clean-all

# Default target
help:
	@echo "Available targets:"
	@echo "  create-ipv6    - Create IPv6 EKS cluster"
	@echo "  create-windows  - Create Windows EKS cluster"
	@echo "  clean-ipv6     - Delete IPv6 EKS cluster"
	@echo "  clean-windows   - Delete Windows EKS cluster"
	@echo "  clean-all       - Delete both clusters"
	@echo ""
	@echo "Usage:"
	@echo "  make create-ipv6    # Create IPv6 cluster"
	@echo "  make create-windows  # Create Windows cluster"
	@echo "  make clean-ipv6      # Delete IPv6 cluster"
	@echo "  make clean-windows   # Delete Windows cluster"
	@echo "  make clean-all       # Delete both clusters"

# Create IPv6 cluster
create-ipv6:
	@echo "Creating IPv6 EKS cluster..."
	eksctl create cluster -f ipv6-eksctl.yaml
	@echo "IPv6 cluster created successfully!"

# Create Windows cluster
create-windows:
	@echo "Creating Windows EKS cluster..."
	eksctl create cluster -f windows.yaml
	@echo "Windows cluster created successfully!"

# Clean up IPv6 cluster
clean-ipv6:
	@echo "Deleting IPv6 EKS cluster..."
	eksctl delete cluster --name=otel-integration-ipv6-cluster --region=eu-west-1
	@echo "IPv6 cluster deleted successfully!"

# Clean up Windows cluster
clean-windows:
	@echo "Deleting Windows EKS cluster..."
	eksctl delete cluster --name=otel-integration-windows-cluster --region=eu-west-1
	@echo "Windows cluster deleted successfully!"

# Clean up both clusters
clean-all: clean-ipv6 clean-windows
	@echo "All clusters cleaned up!" 
