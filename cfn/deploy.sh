#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME=${2:-cfn-hcm-poc}
REGION=${3:-ap-northeast-1}
AWS_PROFILE=${4}

if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
    echo "Error: Environment must be 'dev' or 'prod'"
    echo "Usage: $0 <environment> [project-name] [region] [aws-profile]"
    echo "Example: $0 dev cfn-hcm-poc ap-northeast-1"
    echo "Example: $0 dev cfn-hcm-poc ap-northeast-1 my-profile"
    exit 1
fi

# AWS Profile flag
PROFILE_FLAG=""
if [[ -n "$AWS_PROFILE" ]]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
    echo "Using AWS Profile: $AWS_PROFILE"
fi

echo "Deploying CloudFormation stacks for $ENVIRONMENT environment..."
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

# Deploy VPC Stack
echo "Deploying VPC stack..."
aws cloudformation deploy \
    --template-file vpc-stack.yaml \
    --stack-name cfn-hcm-vpc-$ENVIRONMENT \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset \
    $PROFILE_FLAG

# Deploy ECR Stack
echo "Deploying ECR stack..."
aws cloudformation deploy \
    --template-file ecr-stack.yaml \
    --stack-name cfn-hcm-ecr-$ENVIRONMENT \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset \
    $PROFILE_FLAG

# Deploy ECS Stack
echo "Deploying ECS stack..."
aws cloudformation deploy \
    --template-file ecs-stack.yaml \
    --stack-name cfn-hcm-ecs-$ENVIRONMENT \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --no-fail-on-empty-changeset \
    $PROFILE_FLAG

echo ""
echo "All stacks deployed successfully for $ENVIRONMENT environment!"

# Show outputs
echo ""
echo "Stack outputs:"
aws cloudformation describe-stacks \
    --stack-name cfn-hcm-vpc-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
    --output text \
    $PROFILE_FLAG | xargs -I {} echo "VPC ID: {}"

aws cloudformation describe-stacks \
    --stack-name cfn-hcm-ecr-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`RepositoryUri`].OutputValue' \
    --output text \
    $PROFILE_FLAG | xargs -I {} echo "ECR URI: {}"

aws cloudformation describe-stacks \
    --stack-name cfn-hcm-ecs-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
    --output text \
    $PROFILE_FLAG | xargs -I {} echo "ECS Cluster: {}" 
