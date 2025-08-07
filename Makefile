# Makefile for HCM POC Project
# This file provides convenient commands for Docker and AWS operations

# Project Configuration
PROJECT_NAME := hcm-poc
DOCKER_IMAGE := $(PROJECT_NAME):latest
DOCKER_CONTAINER := $(PROJECT_NAME)-container
CDK_ECR_REPO := cdk-hcm-poc-dev
CFN_ECR_REPO := cfn-hcm-poc-dev
AWS_REGION := ap-northeast-1
ENVIRONMENT := dev

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
	@echo "    ecr-login             - Login to ECR"
	@echo "    ecr-push-cdk          - Build and push to CDK ECR"
	@echo "    ecr-push-cfn          - Build and push to CFN ECR"
	@echo ""
	@echo "  CDK Operations:"
	@echo "    cdk-install           - Install CDK dependencies"
	@echo "    cdk-bootstrap         - Bootstrap CDK"
	@echo "    cdk-diff              - Show diff"
	@echo "    cdk-deploy            - Deploy CDK infrastructure"
	@echo "    cdk-destroy           - Destroy CDK infrastructure"
	@echo ""
	@echo "  CFN Operations:"
	@echo "    cfn-deploy            - Deploy CFN infrastructure"
	@echo "    cfn-destroy           - Destroy CFN infrastructure"
	@echo ""
	@echo "  Profile Usage:"
	@echo "    make <command> PROFILE=my-profile"
	@echo "    Example: make cdk-deploy PROFILE=development"

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
.PHONY: ecr-login
ecr-login:
	aws ecr get-login-password --region $(AWS_REGION) $(AWS_PROFILE_FLAG) | \
	docker login --username AWS --password-stdin $$(aws sts get-caller-identity --query Account --output text $(AWS_PROFILE_FLAG)).dkr.ecr.$(AWS_REGION).amazonaws.com

.PHONY: ecr-push-cdk
ecr-push-cdk: build ecr-login
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text $(AWS_PROFILE_FLAG)))
	docker tag $(DOCKER_IMAGE) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CDK_ECR_REPO):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CDK_ECR_REPO):latest

.PHONY: ecr-push-cfn
ecr-push-cfn: build ecr-login
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text $(AWS_PROFILE_FLAG)))
	docker tag $(DOCKER_IMAGE) $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CFN_ECR_REPO):latest
	docker push $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(CFN_ECR_REPO):latest

# CDK Operations
.PHONY: cdk-install
cdk-install:
	cd cdk && pip install -r requirements.txt

.PHONY: cdk-bootstrap
cdk-bootstrap:
	cd cdk && cdk bootstrap $(CDK_PROFILE_FLAG)

.PHONY: cdk-diff
cdk-diff:
	cd cdk && cdk diff $(CDK_PROFILE_FLAG) --all

.PHONY: cdk-deploy
cdk-deploy:
	cd cdk && cdk deploy $(CDK_PROFILE_FLAG) --all --require-approval never

.PHONY: cdk-destroy
cdk-destroy:
	cd cdk && cdk destroy $(CDK_PROFILE_FLAG) --all --force

# CFN Operations
.PHONY: cfn-deploy
cfn-deploy:
	cd cfn && ./deploy.sh $(ENVIRONMENT) cfn-hcm-poc $(AWS_REGION) $(PROFILE)

.PHONY: cfn-destroy
cfn-destroy:
	cd cfn && ./destroy.sh $(ENVIRONMENT) cfn-hcm-poc $(AWS_REGION) $(PROFILE)

# Development workflow
.PHONY: dev-deploy-cdk
dev-deploy-cdk: ecr-push-cdk cdk-deploy
	@echo "CDK development environment deployed successfully!"

.PHONY: dev-deploy-cfn
dev-deploy-cfn: ecr-push-cfn cfn-deploy
	@echo "CFN development environment deployed successfully!" 
