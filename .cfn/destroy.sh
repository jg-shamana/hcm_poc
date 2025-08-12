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

echo "Destroying CloudFormation stacks for environment: $ENVIRONMENT"
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

echo "Warning: This will delete all resources in the following stacks:"
echo "- ${PROJECT_NAME}-ecs-${ENVIRONMENT}"
echo "- ${PROJECT_NAME}-ecr-${ENVIRONMENT}"
echo "- ${PROJECT_NAME}-vpc-${ENVIRONMENT}"
echo ""

read -p "Are you sure you want to continue? (yes/no): " confirm
if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo "Deleting CloudFormation stacks for $ENVIRONMENT environment..."

# ECS Stack の削除
echo "Deleting ECS stack..."
aws cloudformation delete-stack \
    --stack-name "${PROJECT_NAME}-ecs-${ENVIRONMENT}" \
    --region $REGION

echo "Waiting for ECS stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name "${PROJECT_NAME}-ecs-${ENVIRONMENT}" \
    --region $REGION

echo "ECS stack deleted successfully"

# ECR Stack の削除
echo "Deleting ECR stack..."
aws cloudformation delete-stack \
    --stack-name "${PROJECT_NAME}-ecr-${ENVIRONMENT}" \
    --region $REGION

echo "Waiting for ECR stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name "${PROJECT_NAME}-ecr-${ENVIRONMENT}" \
    --region $REGION

echo "ECR stack deleted successfully"

# VPC Stack の削除
echo "Deleting VPC stack..."
aws cloudformation delete-stack \
    --stack-name "${PROJECT_NAME}-vpc-${ENVIRONMENT}" \
    --region $REGION

echo "Waiting for VPC stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name "${PROJECT_NAME}-vpc-${ENVIRONMENT}" \
    --region $REGION

echo "VPC stack deleted successfully"

echo ""
echo "All stacks have been deleted successfully!"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION" 
