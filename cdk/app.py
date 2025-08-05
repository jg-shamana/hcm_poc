#!/usr/bin/env python3

import aws_cdk as cdk
from infra.ecr_stack import EcrStack
from infra.vpc_stack import VpcStack
from infra.ecs_stack import EcsStack
from config import get_environment_config

app = cdk.App()

environments = ["dev", "prod"]

for env_name in environments:
    config = get_environment_config(env_name)

    # VPCスタックを作成
    VpcStack(
        app,
        f"hcm-vpc-{env_name}",
        env=cdk.Environment(
            account=config["account"],
            region=config["region"]
        ),
        environment_name=env_name,
        config=config
    )

    # ECRスタックを作成
    EcrStack(
        app,
        f"hcm-ecr-{env_name}",
        env=cdk.Environment(
            account=config["account"],
            region=config["region"]
        ),
        environment_name=env_name,
        config=config
    )

    # ECSスタックを作成（VPCとECRに依存）
    EcsStack(
        app,
        f"hcm-ecs-{env_name}",
        env=cdk.Environment(
            account=config["account"],
            region=config["region"]
        ),
        environment_name=env_name,
        config=config
    )

app.synth()
