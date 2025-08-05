from typing import Dict, Any
from constructs import Construct
import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    CfnOutput,
    Tags
)

class VpcStack(Stack):

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
        
        self.vpc = self._create_vpc()
        self._create_vpc_endpoints()
        self._create_outputs()

    def _create_vpc(self) -> ec2.Vpc:
        vpc_config = self.config["vpc"]
        
        vpc = ec2.Vpc(
            self,
            "Vpc",
            ip_addresses=ec2.IpAddresses.cidr(vpc_config["cidr_block"]),
            max_azs=2,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED,
                    cidr_mask=vpc_config["private_subnet_cidr_mask"]
                )
            ],
            nat_gateways=0,
            enable_dns_hostnames=True,
            enable_dns_support=True
        )
        
        for key, value in self.config["tags"].items():
            Tags.of(vpc).add(key, value)
        
        Tags.of(vpc).add("Name", f"{self.config['project_name']}-vpc-{self.environment_name}")
        
        for i, subnet in enumerate(vpc.private_subnets):
            Tags.of(subnet).add("Name", f"{self.config['project_name']}-private-subnet-{self.environment_name}-{i+1}")
            Tags.of(subnet).add("Type", "Private")
        
        return vpc

    def _create_vpc_endpoints(self) -> None:
        vpc_endpoint_sg = ec2.SecurityGroup(
            self,
            "VpcEndpointSecurityGroup",
            vpc=self.vpc,
            description=f"Security group for VPC endpoints in {self.environment_name} environment",
            allow_all_outbound=False
        )
        
        vpc_endpoint_sg.add_ingress_rule(
            peer=ec2.Peer.ipv4(self.vpc.vpc_cidr_block),
            connection=ec2.Port.tcp(443),
            description="Allow HTTPS from VPC"
        )
        
        for key, value in self.config["tags"].items():
            Tags.of(vpc_endpoint_sg).add(key, value)
        
        Tags.of(vpc_endpoint_sg).add("Name", f"{self.config['project_name']}-vpc-endpoint-sg-{self.environment_name}")
        
        s3_endpoint = ec2.GatewayVpcEndpoint(
            self,
            "S3Endpoint",
            vpc=self.vpc,
            service=ec2.GatewayVpcEndpointAwsService.S3,
            subnets=[ec2.SubnetSelection(subnets=self.vpc.isolated_subnets)]
        )
        
        ecr_dkr_endpoint = ec2.InterfaceVpcEndpoint(
            self,
            "EcrDkrEndpoint",
            vpc=self.vpc,
            service=ec2.InterfaceVpcEndpointAwsService.ECR_DOCKER,
            subnets=ec2.SubnetSelection(subnets=self.vpc.isolated_subnets),
            security_groups=[vpc_endpoint_sg],
            private_dns_enabled=True
        )
        
        ecr_api_endpoint = ec2.InterfaceVpcEndpoint(
            self,
            "EcrApiEndpoint",
            vpc=self.vpc,
            service=ec2.InterfaceVpcEndpointAwsService.ECR,
            subnets=ec2.SubnetSelection(subnets=self.vpc.isolated_subnets),
            security_groups=[vpc_endpoint_sg],
            private_dns_enabled=True
        )
        
        logs_endpoint = ec2.InterfaceVpcEndpoint(
            self,
            "LogsEndpoint",
            vpc=self.vpc,
            service=ec2.InterfaceVpcEndpointAwsService.CLOUDWATCH_LOGS,
            subnets=ec2.SubnetSelection(subnets=self.vpc.isolated_subnets),
            security_groups=[vpc_endpoint_sg],
            private_dns_enabled=True
        )
        
        for endpoint in [s3_endpoint, ecr_dkr_endpoint, ecr_api_endpoint, logs_endpoint]:
            for key, value in self.config["tags"].items():
                Tags.of(endpoint).add(key, value)

    def _create_outputs(self) -> None:
        CfnOutput(
            self,
            "VpcId",
            value=self.vpc.vpc_id,
            description=f"VPC ID for {self.environment_name} environment",
            export_name=f"hcm-vpc-{self.environment_name}-vpc-id"
        )
        
        CfnOutput(
            self,
            "VpcCidr",
            value=self.vpc.vpc_cidr_block,
            description=f"VPC CIDR for {self.environment_name} environment",
            export_name=f"hcm-vpc-{self.environment_name}-vpc-cidr"
        )
        
        isolated_subnets = self.vpc.isolated_subnets
        
        for i, subnet in enumerate(isolated_subnets):
            subnet_number = i + 1
            
            CfnOutput(
                self,
                f"PrivateSubnet{subnet_number}Id",
                value=subnet.subnet_id,
                description=f"Private Subnet {subnet_number} ID for {self.environment_name} environment",
                export_name=f"hcm-vpc-{self.environment_name}-private-subnet-{subnet_number}-id"
            )
            
            CfnOutput(
                self,
                f"PrivateSubnet{subnet_number}Cidr",
                value=subnet.ipv4_cidr_block,
                description=f"Private Subnet {subnet_number} CIDR for {self.environment_name} environment",
                export_name=f"hcm-vpc-{self.environment_name}-private-subnet-{subnet_number}-cidr"
            )
            
            CfnOutput(
                self,
                f"PrivateSubnet{subnet_number}Az",
                value=subnet.availability_zone,
                description=f"Private Subnet {subnet_number} AZ for {self.environment_name} environment",
                export_name=f"hcm-vpc-{self.environment_name}-private-subnet-{subnet_number}-az"
            )

    def get_vpc(self) -> ec2.Vpc:
        return self.vpc 
