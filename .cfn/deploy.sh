#!/bin/bash

set -e

# 引数チェック
if [ $# -lt 3 ]; then
    echo "Usage: $0 <environment> <project-name> <region> [profile]"
    echo "Example: $0 dev cfn-hcm-poc ap-northeast-1"
    echo "Example: $0 dev cfn-hcm-poc ap-northeast-1 my-profile"
    exit 1
fi

ENVIRONMENT=$1
PROJECT_NAME=$2
REGION=$3
PROFILE=${4:-}

# プロファイル設定
if [ -n "$PROFILE" ]; then
    export AWS_PROFILE=$PROFILE
    echo "Using AWS profile: $PROFILE"
fi

echo "Deploying CloudFormation stacks for environment: $ENVIRONMENT"
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"

# VPC Stack のデプロイ
echo "Deploying VPC stack..."
aws cloudformation deploy \
    --template-file vpc-stack.yaml \
    --stack-name "${PROJECT_NAME}-vpc-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_IAM \
    --region $REGION

echo "VPC stack deployed successfully"

# ECR Stack のデプロイ
echo "Deploying ECR stack..."
aws cloudformation deploy \
    --template-file ecr-stack.yaml \
    --stack-name "${PROJECT_NAME}-ecr-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_IAM \
    --region $REGION

echo "ECR stack deployed successfully"

# ECS Stack のデプロイ
echo "Deploying ECS stack..."
aws cloudformation deploy \
    --template-file ecs-stack.yaml \
    --stack-name "${PROJECT_NAME}-ecs-${ENVIRONMENT}" \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_IAM \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

echo "ECS stack deployed successfully"

echo "All stacks deployed successfully!"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"

# デプロイされたリソースの確認
echo ""
echo "Stack status:"
aws cloudformation describe-stacks \
    --stack-name "${PROJECT_NAME}-vpc-${ENVIRONMENT}" \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text

aws cloudformation describe-stacks \
    --stack-name "${PROJECT_NAME}-ecr-${ENVIRONMENT}" \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text

aws cloudformation describe-stacks \
    --stack-name "${PROJECT_NAME}-ecs-${ENVIRONMENT}" \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text 
