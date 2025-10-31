import os
from typing import Dict, Any

def get_environment_config(environment: str) -> Dict[str, Any]:

    base_config = {
        "project_name": "cdk-hcm-poc",
        "tags": {
            "Project": "HCM-POC",
            "Environment": environment,
            "ManagedBy": "CDK"
        }
    }

    environment_configs = {
        "dev": {
            **base_config,
            "account": os.getenv("CDK_DEFAULT_ACCOUNT"),
            "region": os.getenv("CDK_DEFAULT_REGION", "ap-northeast-1"),
            "vpc": {
                "cidr_block": "10.0.0.0/16",
                "public_subnet_cidr_mask": 24,
                "private_subnet_cidr_mask": 24
            },
            "cloudmap": {
                "namespace_name": "dev.hcm.sample.co.jp",
                "namespace_id_export_name": "cloudmap-namespace-id-dev",
                "namespace_arn_export_name": "cloudmap-namespace-arn-dev"
            },
            "ecr": {
                "repository_name": "cdk-hcm-poc-dev",
                "image_tag_mutability": "MUTABLE",
                "scan_on_push": True,
                "lifecycle_policy": {
                    "max_image_count": 10
                }
            },
            "ecs": {
                "cpu": 256,
                "memory": 512,
                "desired_count": 1
            }
        },
        "prod": {
            **base_config,
            "account": os.getenv("CDK_DEFAULT_ACCOUNT"),
            "region": os.getenv("CDK_DEFAULT_REGION", "ap-northeast-1"),
            "vpc": {
                "cidr_block": "10.1.0.0/16",
                "public_subnet_cidr_mask": 24,
                "private_subnet_cidr_mask": 24
            },
            "cloudmap": {
                "namespace_name": "prod.hcm.internal",
                "namespace_id_export_name": "cloudmap-namespace-id-prod",
                "namespace_arn_export_name": "cloudmap-namespace-arn-prod"
            },
            "ecr": {
                "repository_name": "cdk-hcm-poc-prod",
                "image_tag_mutability": "IMMUTABLE",
                "scan_on_push": True,
                "lifecycle_policy": {
                    "max_image_count": 50
                }
            },
            "ecs": {
                "cpu": 512,
                "memory": 1024,
                "desired_count": 0
            }
        }
    }

    if environment not in environment_configs:
        raise ValueError(f"Unknown environment: {environment}. Available: {list(environment_configs.keys())}")

    return environment_configs[environment]

def get_all_environments() -> list:
    return ["dev", "prod"] 
