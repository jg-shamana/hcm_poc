#!/usr/bin/env python3

import aws_cdk as cdk
from infra.ecr_stack import EcrStack
from infra.vpc_stack import VpcStack
from infra.ecs_stack import EcsStack
from config import get_environment_config

app = cdk.App()

# environments = ["dev", "prod"]
environments = ["dev"]

for env_name in environments:
    config = get_environment_config(env_name)

    vpc_stack = VpcStack(
        app,
        f"cdk-hcm-vpc-{env_name}",
        env=cdk.Environment(
            account=config["account"],
            region=config["region"]
        ),
        environment_name=env_name,
        config=config
    )

    ecr_stack = EcrStack(
        app,
        f"cdk-hcm-ecr-{env_name}",
        env=cdk.Environment(
            account=config["account"],
            region=config["region"]
        ),
        environment_name=env_name,
        config=config
    )

    ecs_stack = EcsStack(
        app,
        f"cdk-hcm-ecs-{env_name}",
        env=cdk.Environment(
            account=config["account"],
            region=config["region"]
        ),
        environment_name=env_name,
        config=config
    )

    # 依存関係の明示的な設定
    ecs_stack.add_dependency(vpc_stack)
    ecs_stack.add_dependency(ecr_stack)

app.synth()
