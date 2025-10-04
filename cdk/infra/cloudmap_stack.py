from typing import Dict, Any
from constructs import Construct
import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_servicediscovery as sd,
    CfnOutput,
    Tags
)


class CloudMapStack(Stack):

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

        self.vpc = self._import_vpc()
        self.namespace = self._create_private_dns_namespace()
        self._create_outputs()

    def _import_vpc(self) -> ec2.IVpc:
        return ec2.Vpc.from_vpc_attributes(
            self,
            "ImportedVpcForCloudMap",
            vpc_id=cdk.Fn.import_value(f"cdk-hcm-vpc-{self.environment_name}-vpc-id"),
            availability_zones=[
                cdk.Fn.select(0, cdk.Fn.get_azs()),
                cdk.Fn.select(1, cdk.Fn.get_azs())
            ]
        )

    def _create_private_dns_namespace(self) -> sd.PrivateDnsNamespace:
        namespace_name = self.config["cloudmap"]["namespace_name"]
        namespace = sd.PrivateDnsNamespace(
            self,
            "PrivateDnsNamespace",
            name=namespace_name,
            vpc=self.vpc,
            description=f"Cloud Map private DNS namespace for {self.environment_name}"
        )

        for key, value in self.config["tags"].items():
            Tags.of(namespace).add(key, value)

        Tags.of(namespace).add("Name", f"{self.config['project_name']}-cloudmap-ns-{self.environment_name}")

        return namespace

    def _create_outputs(self) -> None:
        CfnOutput(
            self,
            "CloudMapNamespaceId",
            value=self.namespace.namespace_id,
            description=f"Cloud Map namespace ID for {self.environment_name} environment",
            export_name=self.config["cloudmap"]["namespace_id_export_name"]
        )

        CfnOutput(
            self,
            "CloudMapNamespaceArn",
            value=self.namespace.namespace_arn,
            description=f"Cloud Map namespace ARN for {self.environment_name} environment",
            export_name=self.config["cloudmap"]["namespace_arn_export_name"]
        )
