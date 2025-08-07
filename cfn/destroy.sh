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

echo "WARNING: This will DELETE all CloudFormation stacks for $ENVIRONMENT environment!"
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

# Confirmation for production
if [[ "$ENVIRONMENT" == "prod" ]]; then
    echo "⚠️  You are about to delete PRODUCTION resources!"
    read -p "Type 'DELETE PRODUCTION' to confirm: " confirm
    if [[ "$confirm" != "DELETE PRODUCTION" ]]; then
        echo "Cancelled."
        exit 1
    fi
else
    read -p "Type 'yes' to confirm deletion: " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        exit 1
    fi
fi

echo ""
echo "Deleting CloudFormation stacks for $ENVIRONMENT environment..."

# Delete ECS Stack first (dependent on VPC and ECR)
echo "Deleting ECS stack..."
aws cloudformation delete-stack \
    --stack-name cfn-hcm-ecs-$ENVIRONMENT \
    --region $REGION \
    $PROFILE_FLAG

echo "Waiting for ECS stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name cfn-hcm-ecs-$ENVIRONMENT \
    --region $REGION \
    $PROFILE_FLAG

# Delete ECR Stack
echo "Deleting ECR stack..."
aws cloudformation delete-stack \
    --stack-name cfn-hcm-ecr-$ENVIRONMENT \
    --region $REGION \
    $PROFILE_FLAG

echo "Waiting for ECR stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name cfn-hcm-ecr-$ENVIRONMENT \
    --region $REGION \
    $PROFILE_FLAG

# Delete VPC Stack last
echo "Deleting VPC stack..."
aws cloudformation delete-stack \
    --stack-name cfn-hcm-vpc-$ENVIRONMENT \
    --region $REGION \
    $PROFILE_FLAG

echo "Waiting for VPC stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name cfn-hcm-vpc-$ENVIRONMENT \
    --region $REGION \
    $PROFILE_FLAG

echo ""
echo "All stacks deleted successfully for $ENVIRONMENT environment!" 
