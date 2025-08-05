from typing import Dict, Any
from constructs import Construct
import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ecr as ecr,
    CfnOutput,
    RemovalPolicy,
    Tags
)

class EcrStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        environment_name: str,
        config: Dict[str, Any],
        **kwargs
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.environment_name = environment_name
        self.config = config

        self.ecr_repository = self._create_ecr_repository()

        self._create_outputs()

    def _create_ecr_repository(self) -> ecr.Repository:
        ecr_config = self.config["ecr"]

        lifecycle_rules = [
            ecr.LifecycleRule(
                description=f"Keep only {ecr_config['lifecycle_policy']['max_image_count']} images",
                max_image_count=ecr_config["lifecycle_policy"]["max_image_count"],
                rule_priority=1
            )
        ]

        repository = ecr.Repository(
            self,
            "Repository",
            repository_name=ecr_config["repository_name"],
            image_tag_mutability=ecr.TagMutability.MUTABLE if ecr_config["image_tag_mutability"] == "MUTABLE" else ecr.TagMutability.IMMUTABLE,
            image_scan_on_push=ecr_config["scan_on_push"],
            lifecycle_rules=lifecycle_rules,
            removal_policy=RemovalPolicy.DESTROY if self.environment_name == "dev" else RemovalPolicy.RETAIN
        )

        for key, value in self.config["tags"].items():
            Tags.of(repository).add(key, value)

        return repository

    def _create_outputs(self) -> None:
        CfnOutput(
            self,
            "RepositoryUri",
            value=self.ecr_repository.repository_uri,
            description=f"ECR Repository URI for {self.environment_name} environment",
            export_name=f"hcm-ecr-{self.environment_name}-repository-uri"
        )

        CfnOutput(
            self,
            "RepositoryName",
            value=self.ecr_repository.repository_name,
            description=f"ECR Repository Name for {self.environment_name} environment",
            export_name=f"hcm-ecr-{self.environment_name}-repository-name"
        )

        CfnOutput(
            self,
            "RepositoryArn",
            value=self.ecr_repository.repository_arn,
            description=f"ECR Repository ARN for {self.environment_name} environment",
            export_name=f"hcm-ecr-{self.environment_name}-repository-arn"
        )
