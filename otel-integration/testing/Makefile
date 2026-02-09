# Makefile for managing IPv6 EKS test cluster
# Prerequisites: eksctl, kubectl, aws CLI configured

.PHONY: help create-ipv6 clean-ipv6 clean-all

# Default target
help:
	@echo "Available targets:"
	@echo "  create-ipv6    - Create IPv6 EKS cluster"
	@echo "  clean-ipv6     - Delete IPv6 EKS cluster"
	@echo "  clean-all       - Delete IPv6 cluster"
	@echo ""
	@echo "Windows EKS workflow:"
	@echo "  See ./windows-eks/README.md and ./windows-eks/Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make create-ipv6    # Create IPv6 cluster"
	@echo "  make clean-ipv6      # Delete IPv6 cluster"
	@echo "  make clean-all       # Delete IPv6 cluster"

# Create IPv6 cluster
create-ipv6:
	@echo "Creating IPv6 EKS cluster..."
	eksctl create cluster -f ipv6-eksctl.yaml
	@echo "IPv6 cluster created successfully!"

# Clean up IPv6 cluster
clean-ipv6:
	@echo "Deleting IPv6 EKS cluster..."
	eksctl delete cluster --name=otel-integration-ipv6-cluster --region=eu-west-1
	@echo "IPv6 cluster deleted successfully!"

# Clean up IPv6 cluster
clean-all: clean-ipv6
	@echo "IPv6 cluster cleaned up!"
