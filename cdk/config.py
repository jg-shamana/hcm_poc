import os
from typing import Dict, Any

def get_environment_config(environment: str) -> Dict[str, Any]:

    base_config = {
        "project_name": "hcm-poc",
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
                "private_subnet_cidr_mask": 24
            },
            "ecr": {
                "repository_name": "hcm-poc-dev",
                "image_tag_mutability": "MUTABLE",
                "scan_on_push": True,
                "lifecycle_policy": {
                    "max_image_count": 10
                }
            },
            "ecs": {
                "cpu": 256,
                "memory": 512,
                "desired_count": 0
            }
        },
        "prod": {
            **base_config,
            "account": os.getenv("CDK_DEFAULT_ACCOUNT"),
            "region": os.getenv("CDK_DEFAULT_REGION", "ap-northeast-1"),
            "vpc": {
                "cidr_block": "10.1.0.0/16",
                "private_subnet_cidr_mask": 24
            },
            "ecr": {
                "repository_name": "hcm-poc-prod",
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
