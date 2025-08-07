# Makefile for HCM POC Project
# This file provides convenient commands for Docker and AWS operations

# Project Configuration
PROJECT_NAME := hcm-poc
DOCKER_IMAGE := $(PROJECT_NAME):latest
DOCKER_CONTAINER := $(PROJECT_NAME)-container
CDK_ECR_REPO_DEV := cdk-hcm-poc-dev
CDK_ECR_REPO_PROD := cdk-hcm-poc-prod
AWS_REGION := ap-northeast-1

# Environment Variables
ENV_DEV := dev
ENV_PROD := prod

# Check if profile is specified
ifdef PROFILE
	AWS_PROFILE_FLAG := --profile $(PROFILE)
	CDK_PROFILE_FLAG := --profile $(PROFILE)
else
	AWS_PROFILE_FLAG :=
	CDK_PROFILE_FLAG :=
endif

# Help target
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  Docker Operations:"
	@echo "    build                 - Build Docker image"
	@echo "    run                   - Run container locally"
	@echo "    stop                  - Stop and remove container"
	@echo "    clean                 - Remove container and image"
	@echo ""
	@echo "  AWS CLI Operations:"
	@echo "    aws-configure         - Configure AWS CLI"
	@echo "    aws-whoami            - Show current AWS identity"
	@echo ""
	@echo "  ECR Operations:"
	@echo "    ecr-login-dev         - Login to ECR for dev"
	@echo "    ecr-login-prod        - Login to ECR for prod"
	@echo "    ecr-push-dev          - Build and push to dev ECR"
	@echo "    ecr-push-prod         - Build and push to prod ECR"
	@echo ""
	@echo "  CDK Operations:"
	@echo "    cdk-install           - Install CDK dependencies"
	@echo "    cdk-bootstrap-dev     - Bootstrap CDK for dev"
	@echo "    cdk-bootstrap-prod    - Bootstrap CDK for prod"
	@echo "    cdk-diff-dev          - Show diff for dev"
	@echo "    cdk-diff-prod         - Show diff for prod"
	@echo "    cdk-deploy-dev        - Deploy dev environment"
	@echo "    cdk-deploy-prod       - Deploy prod environment"
	@echo "    cdk-destroy-dev       - Destroy dev environment"
	@echo "    cdk-destroy-prod      - Destroy prod environment"
	@echo ""
	@echo "  Profile Usage:"
	@echo "    make <command> PROFILE=my-profile"
	@echo "    Example: make cdk-deploy-dev PROFILE=development"

# Docker Operations
.PHONY: build
build:
	docker build -t $(DOCKER_IMAGE) .

.PHONY: run
run: build
	docker run -d --name $(DOCKER_CONTAINER) $(DOCKER_IMAGE)
	@echo "Container $(DOCKER_CONTAINER) is running"
	@echo "View logs with: docker logs -f $(DOCKER_CONTAINER)"

.PHONY: stop
stop:
	docker stop $(DOCKER_CONTAINER) 2>/dev/null || true
	docker rm $(DOCKER_CONTAINER) 2>/dev/null || true
	@echo "Container $(DOCKER_CONTAINER) stopped and removed"

.PHONY: clean
clean: stop
	docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@echo "Image $(DOCKER_IMAGE) removed"

# AWS CLI Operations
.PHONY: aws-configure
aws-configure:
	aws configure $(AWS_PROFILE_FLAG)

.PHONY: aws-whoami
aws-whoami:
	aws sts get-caller-identity $(AWS_PROFILE_FLAG)

# ECR Operations
.PHONY: ecr-login-dev
ecr-login-dev:
	aws ecr get-login-password --region $(AWS_REGION) $(AWS_PROFILE_FLAG) | \
	docker login --username AWS --password-stdin $$(aws sts get-caller-identity --query Account --output text $(AWS_PROFILE_FLAG)).dkr.ecr.$(AWS_REGION).amazonaws.com

.PHONY: ecr-login-prod
ecr-login-prod:
	aws ecr get-login-password --region $(AWS_REGION) $(AWS_PROFILE_FLAG) | \
	docker login --username AWS --password-stdin $$(aws sts get-caller-identity --query Account --output text $(AWS_PROFILE_FLAG)).dkr.ecr.$(AWS_REGION).amazonaws.com

.PHONY: ecr-push-dev
ecr-push-dev: build ecr-login-dev
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text $(AWS_PROFILE_FLAG)))
	docker tag $(DOCKER_IMAGE) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CDK_ECR_REPO_DEV):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CDK_ECR_REPO_DEV):latest

.PHONY: ecr-push-prod
ecr-push-prod: build ecr-login-prod
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text $(AWS_PROFILE_FLAG)))
	docker tag $(DOCKER_IMAGE) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CDK_ECR_REPO_PROD):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CDK_ECR_REPO_PROD):latest

# CDK Operations
.PHONY: cdk-install
cdk-install:
	cd cdk && pip install -r requirements.txt

.PHONY: cdk-bootstrap-dev
cdk-bootstrap-dev:
	cd cdk && cdk bootstrap $(CDK_PROFILE_FLAG) --qualifier $(ENV_DEV)

.PHONY: cdk-bootstrap-prod
cdk-bootstrap-prod:
	cd cdk && cdk bootstrap $(CDK_PROFILE_FLAG) --qualifier $(ENV_PROD)

.PHONY: cdk-diff-dev
cdk-diff-dev:
	cd cdk && cdk diff $(CDK_PROFILE_FLAG) --all

.PHONY: cdk-diff-prod
cdk-diff-prod:
	cd cdk && cdk diff $(CDK_PROFILE_FLAG) --all

.PHONY: cdk-deploy-dev
cdk-deploy-dev:
	cd cdk && cdk deploy $(CDK_PROFILE_FLAG) --all --require-approval never

.PHONY: cdk-deploy-prod
cdk-deploy-prod:
	cd cdk && cdk deploy $(CDK_PROFILE_FLAG) --all --require-approval never

.PHONY: cdk-destroy-dev
cdk-destroy-dev:
	cd cdk && cdk destroy $(CDK_PROFILE_FLAG) --all --force

.PHONY: cdk-destroy-prod
cdk-destroy-prod:
	cd cdk && cdk destroy $(CDK_PROFILE_FLAG) --all --force

# Development workflow
.PHONY: dev-deploy
dev-deploy: ecr-push-dev cdk-deploy-dev
	@echo "Development environment deployed successfully!"

.PHONY: prod-deploy
prod-deploy: ecr-push-prod cdk-deploy-prod
	@echo "Production environment deployed successfully!" 
