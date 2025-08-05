# AWS Profile support
AWS_PROFILE_FLAG := $(if $(AWS_PROFILE),--profile $(AWS_PROFILE))
CDK_PROFILE_FLAG := $(if $(AWS_PROFILE),--profile $(AWS_PROFILE))

.PHONY: help dev-diff dev-deploy prod-diff prod-deploy check-aws cdk-install all-diff all-deploy

help: ## ヘルプを表示
	@echo "=== CDK デプロイメント管理 ==="
	@echo "AWS Profile指定方法: AWS_PROFILE=profile-name make [command]"
	@echo "例: AWS_PROFILE=dev-account make dev-deploy"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# === AWS Setup ===
check-aws: ## AWS CLIとクレデンシャルの設定状況を確認
	@echo "=== AWS Setup Check ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@which aws > /dev/null 2>&1 && echo "✓ AWS CLI installed" || echo "✗ AWS CLI not found"
	@aws --version 2>/dev/null || echo "✗ AWS CLI not working"
	@aws $(AWS_PROFILE_FLAG) sts get-caller-identity 2>/dev/null && echo "✓ AWS credentials configured" || echo "✗ AWS credentials not configured"
	@which cdk > /dev/null 2>&1 && echo "✓ CDK CLI installed" || echo "✗ CDK CLI not found"

cdk-install: ## CDK依存関係をインストール
	@echo "=== Installing CDK Dependencies ==="
	cd cdk && pip install -r requirements.txt
	npm install -g aws-cdk

setup-profile: ## AWSプロファイルの設定方法を表示
	@echo "=== AWS Profile Setup Guide ==="
	@echo ""
	@echo "1. 新しいプロファイルを作成："
	@echo "   aws configure --profile dev-account"
	@echo "   aws configure --profile prod-account"
	@echo ""
	@echo "2. 既存プロファイルを確認："
	@echo "   aws configure list-profiles"
	@echo ""
	@echo "3. プロファイルの設定を確認："
	@echo "   aws configure list --profile dev-account"
	@echo ""
	@echo "4. 使用例："
	@echo "   AWS_PROFILE=dev-account make check-aws"

# === Dev Environment ===
dev-diff: check-aws ## dev環境の差分を表示（全スタック）
	@echo "=== Showing Diff for Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-vpc-dev hcm-ecr-dev hcm-ecs-dev $(CDK_PROFILE_FLAG)

dev-vpc-diff: check-aws ## dev環境VPCの差分を表示
	@echo "=== Showing VPC Diff for Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-vpc-dev $(CDK_PROFILE_FLAG)

dev-ecr-diff: check-aws ## dev環境ECRの差分を表示
	@echo "=== Showing ECR Diff for Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-ecr-dev $(CDK_PROFILE_FLAG)

dev-ecs-diff: check-aws ## dev環境ECSの差分を表示
	@echo "=== Showing ECS Diff for Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-ecs-dev $(CDK_PROFILE_FLAG)

dev-deploy: check-aws ## dev環境にデプロイ（全スタック）
	@echo "=== Deploying to Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk deploy hcm-vpc-dev hcm-ecr-dev hcm-ecs-dev --require-approval never $(CDK_PROFILE_FLAG)
	@echo "✓ Dev environment deployed successfully"
	@echo "VPC ID:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-dev --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text
	@echo "Repository URI:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecr-dev --query 'Stacks[0].Outputs[?OutputKey==`RepositoryUri`].OutputValue' --output text
	@echo "ECS Cluster:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-dev --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' --output text

dev-vpc-deploy: check-aws ## dev環境VPCのみデプロイ
	@echo "=== Deploying VPC to Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk deploy hcm-vpc-dev --require-approval never $(CDK_PROFILE_FLAG)
	@echo "✓ Dev VPC deployed successfully"

dev-ecr-deploy: check-aws ## dev環境ECRのみデプロイ
	@echo "=== Deploying ECR to Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk deploy hcm-ecr-dev --require-approval never $(CDK_PROFILE_FLAG)
	@echo "✓ Dev ECR deployed successfully"

dev-ecs-deploy: check-aws ## dev環境ECSのみデプロイ
	@echo "=== Deploying ECS to Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk deploy hcm-ecs-dev --require-approval never $(CDK_PROFILE_FLAG)
	@echo "✓ Dev ECS deployed successfully"

dev-destroy: check-aws ## dev環境のリソースを削除（全スタック）
	@echo "=== Destroying Dev Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk destroy hcm-ecs-dev hcm-ecr-dev hcm-vpc-dev --force $(CDK_PROFILE_FLAG)

# === Prod Environment ===
prod-diff: check-aws ## prod環境の差分を表示（全スタック）
	@echo "=== Showing Diff for Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-vpc-prod hcm-ecr-prod hcm-ecs-prod $(CDK_PROFILE_FLAG)

prod-vpc-diff: check-aws ## prod環境VPCの差分を表示
	@echo "=== Showing VPC Diff for Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-vpc-prod $(CDK_PROFILE_FLAG)

prod-ecr-diff: check-aws ## prod環境ECRの差分を表示
	@echo "=== Showing ECR Diff for Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-ecr-prod $(CDK_PROFILE_FLAG)

prod-ecs-diff: check-aws ## prod環境ECSの差分を表示
	@echo "=== Showing ECS Diff for Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk diff hcm-ecs-prod $(CDK_PROFILE_FLAG)

prod-deploy: check-aws ## prod環境にデプロイ（全スタック、承認が必要）
	@echo "=== Deploying to Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "⚠️  Production deployment requires manual approval"
	cd cdk && cdk deploy hcm-vpc-prod hcm-ecr-prod hcm-ecs-prod $(CDK_PROFILE_FLAG)
	@echo "✓ Prod environment deployed successfully"
	@echo "VPC ID:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-prod --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text
	@echo "Repository URI:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecr-prod --query 'Stacks[0].Outputs[?OutputKey==`RepositoryUri`].OutputValue' --output text
	@echo "ECS Cluster:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-prod --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' --output text

prod-vpc-deploy: check-aws ## prod環境VPCのみデプロイ
	@echo "=== Deploying VPC to Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "⚠️  Production VPC deployment requires manual approval"
	cd cdk && cdk deploy hcm-vpc-prod $(CDK_PROFILE_FLAG)
	@echo "✓ Prod VPC deployed successfully"

prod-ecr-deploy: check-aws ## prod環境ECRのみデプロイ
	@echo "=== Deploying ECR to Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "⚠️  Production ECR deployment requires manual approval"
	cd cdk && cdk deploy hcm-ecr-prod $(CDK_PROFILE_FLAG)
	@echo "✓ Prod ECR deployed successfully"

prod-ecs-deploy: check-aws ## prod環境ECSのみデプロイ
	@echo "=== Deploying ECS to Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "⚠️  Production ECS deployment requires manual approval"
	cd cdk && cdk deploy hcm-ecs-prod $(CDK_PROFILE_FLAG)
	@echo "✓ Prod ECS deployed successfully"

prod-destroy: check-aws ## prod環境のリソースを削除（確認が必要）
	@echo "=== Destroying Prod Environment ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "⚠️  This will destroy production resources!"
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd cdk && cdk destroy hcm-ecs-prod hcm-ecr-prod hcm-vpc-prod --force $(CDK_PROFILE_FLAG)

# === All Environments ===
all-diff: dev-diff prod-diff ## 全環境の差分を表示

all-deploy: dev-deploy prod-deploy ## 全環境にデプロイ（dev -> prod順）

# === Utility Commands ===
synth: ## CDKテンプレートを生成
	@echo "=== Synthesizing CDK Templates ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk synth $(CDK_PROFILE_FLAG)

bootstrap: check-aws ## CDKブートストラップを実行
	@echo "=== CDK Bootstrap ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	cd cdk && cdk bootstrap $(CDK_PROFILE_FLAG)

status: check-aws ## スタックの状態を確認
	@echo "=== Stack Status ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "Dev Environment:"
	@echo "  VPC Stack:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-dev --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "  Stack not found"
	@echo "  ECR Stack:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecr-dev --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "  Stack not found"
	@echo "  ECS Stack:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-dev --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "  Stack not found"
	@echo "Prod Environment:"
	@echo "  VPC Stack:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-prod --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "  Stack not found"
	@echo "  ECR Stack:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecr-prod --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "  Stack not found"
	@echo "  ECS Stack:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-prod --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "  Stack not found"

list-repos: check-aws ## ECRリポジトリ一覧を表示
	@echo "=== ECR Repositories ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@aws $(AWS_PROFILE_FLAG) ecr describe-repositories --query 'repositories[?contains(repositoryName, `hcm-git-monitor`)].{Name:repositoryName,URI:repositoryUri,Created:createdAt}' --output table 2>/dev/null || echo "No repositories found"

list-vpcs: check-aws ## VPC一覧を表示
	@echo "=== VPC Information ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "Dev VPC:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-dev --query 'Stacks[0].Outputs[?OutputKey==`VpcId` || OutputKey==`VpcCidr`].{Key:OutputKey,Value:OutputValue}' --output table 2>/dev/null || echo "  VPC not found"
	@echo "Prod VPC:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-prod --query 'Stacks[0].Outputs[?OutputKey==`VpcId` || OutputKey==`VpcCidr`].{Key:OutputKey,Value:OutputValue}' --output table 2>/dev/null || echo "  VPC not found"

list-subnets: check-aws ## サブネット一覧を表示
	@echo "=== Subnet Information ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "Dev Subnets:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-dev --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetIds` || OutputKey==`PrivateSubnetCidrs` || OutputKey==`AvailabilityZones`].{Key:OutputKey,Value:OutputValue}' --output table 2>/dev/null || echo "  Subnets not found"
	@echo "Prod Subnets:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-vpc-prod --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetIds` || OutputKey==`PrivateSubnetCidrs` || OutputKey==`AvailabilityZones`].{Key:OutputKey,Value:OutputValue}' --output table 2>/dev/null || echo "  Subnets not found"

list-ecs-clusters: check-aws ## ECSクラスター一覧を表示
	@echo "=== ECS Cluster Information ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "Dev ECS Cluster:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-dev --query 'Stacks[0].Outputs[?OutputKey==`ClusterName` || OutputKey==`ServiceName`].{Key:OutputKey,Value:OutputValue}' --output table 2>/dev/null || echo "  ECS Cluster not found"
	@echo "Prod ECS Cluster:"
	@cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-prod --query 'Stacks[0].Outputs[?OutputKey==`ClusterName` || OutputKey==`ServiceName`].{Key:OutputKey,Value:OutputValue}' --output table 2>/dev/null || echo "  ECS Cluster not found"

list-ecs-tasks: check-aws ## ECSタスク状態を表示
	@echo "=== ECS Tasks Status ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@echo "Dev Environment Tasks:"
	@DEV_CLUSTER=$$(cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-dev --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' --output text 2>/dev/null); \
	if [ ! -z "$$DEV_CLUSTER" ]; then \
		aws $(AWS_PROFILE_FLAG) ecs list-tasks --cluster $$DEV_CLUSTER --query 'taskArns[*]' --output table 2>/dev/null || echo "  No tasks found"; \
	else \
		echo "  ECS Cluster not found"; \
	fi
	@echo "Prod Environment Tasks:"
	@PROD_CLUSTER=$$(cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecs-prod --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' --output text 2>/dev/null); \
	if [ ! -z "$$PROD_CLUSTER" ]; then \
		aws $(AWS_PROFILE_FLAG) ecs list-tasks --cluster $$PROD_CLUSTER --query 'taskArns[*]' --output table 2>/dev/null || echo "  No tasks found"; \
	else \
		echo "  ECS Cluster not found"; \
	fi

# === Docker Integration ===
build: ## Dockerイメージをビルド
	@echo "=== Building Docker Image ==="
	docker-compose build

push-dev: build check-aws ## DockerイメージをECR dev環境にプッシュ
	@echo "=== Pushing to Dev ECR ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@ECR_URI=$$(cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecr-dev --query 'Stacks[0].Outputs[?OutputKey==`RepositoryUri`].OutputValue' --output text 2>/dev/null); \
	if [ -z "$$ECR_URI" ]; then \
		echo "❌ Dev ECR repository not found. Deploy first with 'make dev-deploy'"; \
		exit 1; \
	fi; \
	echo "Logging into ECR..."; \
	aws $(AWS_PROFILE_FLAG) ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin $$ECR_URI; \
	echo "Tagging and pushing image..."; \
	docker tag hcm_poc-commit-checker:latest $$ECR_URI:latest; \
	docker push $$ECR_URI:latest; \
	echo "✓ Image pushed to $$ECR_URI:latest"

push-prod: build check-aws ## DockerイメージをECR prod環境にプッシュ
	@echo "=== Pushing to Prod ECR ==="
	$(if $(AWS_PROFILE),@echo "Using AWS Profile: $(AWS_PROFILE)")
	@ECR_URI=$$(cd cdk && aws $(AWS_PROFILE_FLAG) cloudformation describe-stacks --stack-name hcm-ecr-prod --query 'Stacks[0].Outputs[?OutputKey==`RepositoryUri`].OutputValue' --output text 2>/dev/null); \
	if [ -z "$$ECR_URI" ]; then \
		echo "❌ Prod ECR repository not found. Deploy first with 'make prod-deploy'"; \
		exit 1; \
	fi; \
	echo "Logging into ECR..."; \
	aws $(AWS_PROFILE_FLAG) ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin $$ECR_URI; \
	echo "Tagging and pushing image..."; \
	docker tag hcm_poc-commit-checker:latest $$ECR_URI:latest; \
	docker push $$ECR_URI:latest; \
	echo "✓ Image pushed to $$ECR_URI:latest"

# === Quick Start ===
setup: cdk-install bootstrap ## 初期セットアップ（CDKインストール + ブートストラップ）
	@echo "=== Setup Complete ==="
	@echo "Next: Run 'make dev-deploy' to deploy dev environment"

dev-full: dev-deploy push-dev ## dev環境の完全デプロイ（VPC+ECR+ECS作成 + Dockerプッシュ）

prod-full: prod-deploy push-prod ## prod環境の完全デプロイ（VPC+ECR+ECS作成 + Dockerプッシュ）

# === Profile Usage Examples ===
show-profile-examples: ## AWSプロファイル使用例を表示
	@echo "=== AWS Profile 使用例 ==="
	@echo ""
	@echo "1. デフォルトプロファイル使用："
	@echo "   make dev-deploy"
	@echo ""
	@echo "2. dev-accountプロファイル使用："
	@echo "   AWS_PROFILE=dev-account make dev-deploy"
	@echo ""
	@echo "3. prod-accountプロファイル使用："
	@echo "   AWS_PROFILE=prod-account make prod-deploy"
	@echo ""
	@echo "4. プロファイル使用時の確認："
	@echo "   AWS_PROFILE=your-profile make check-aws"
	@echo ""
	@echo "5. 複数コマンドでプロファイル維持："
	@echo "   export AWS_PROFILE=dev-account"
	@echo "   make dev-diff"
	@echo "   make dev-deploy" 
