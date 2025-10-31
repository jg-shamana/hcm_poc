from typing import Dict, Any
from constructs import Construct
import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ecs as ecs,
    aws_ec2 as ec2,
    aws_autoscaling as autoscaling,
    aws_ecr as ecr,
    aws_logs as logs,
    aws_iam as iam,
    RemovalPolicy,
    CfnOutput,
    Tags,
)


class EcsEc2Stack(Stack):

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

        self.vpc = ec2.Vpc.from_vpc_attributes(
            self,
            "ImportedVpc",
            vpc_id=cdk.Fn.import_value(f"cdk-hcm-vpc-{self.environment_name}-vpc-id"),
            availability_zones=[
                cdk.Fn.select(0, cdk.Fn.get_azs()),
                cdk.Fn.select(1, cdk.Fn.get_azs()),
            ],
        )

        self.instance_sg = ec2.SecurityGroup(
            self,
            "EcsInstanceSecurityGroup",
            vpc=self.vpc,
            description=f"Security group for ECS instances in {self.environment_name}",
            allow_all_outbound=True,
        )
        for key, value in self.config["tags"].items():
            Tags.of(self.instance_sg).add(key, value)
        Tags.of(self.instance_sg).add("Name", f"{self.config['project_name']}-ecs-instance-sg-{self.environment_name}")

        self.task_sg = ec2.SecurityGroup(
            self,
            "EcsTaskSecurityGroup",
            vpc=self.vpc,
            description=f"Security group for ECS tasks in {self.environment_name}",
            allow_all_outbound=True,
        )
        for key, value in self.config["tags"].items():
            Tags.of(self.task_sg).add(key, value)
        Tags.of(self.task_sg).add("Name", f"{self.config['project_name']}-ecs-task-sg-ec2-{self.environment_name}")

        self.cluster = ecs.Cluster(
            self,
            "EcsEc2Cluster",
            vpc=self.vpc,
            cluster_name=f"{self.config['project_name']}-cluster-ec2-{self.environment_name}",
            container_insights=True,
        )

        private_subnets = []
        for i in range(2):
            subnet_id = cdk.Fn.import_value(f"cdk-hcm-vpc-{self.environment_name}-private-subnet-{i+1}-id")
            subnet = ec2.Subnet.from_subnet_id(self, f"PrivateSubnetEc2{i+1}", subnet_id)
            private_subnets.append(subnet)

        instance_role = iam.Role(
            self,
            "EcsInstanceRole",
            assumed_by=iam.ServicePrincipal("ec2.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonEC2ContainerServiceforEC2Role"),
                iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore"),
            ],
        )

        asg = autoscaling.AutoScalingGroup(
            self,
            "EcsAsg",
            vpc=self.vpc,
            instance_type=ec2.InstanceType("t3.small"),
            machine_image=ecs.EcsOptimizedImage.amazon_linux2(),
            min_capacity=1,
            max_capacity=2,
            desired_capacity=1,
            vpc_subnets=ec2.SubnetSelection(subnets=private_subnets),
            security_group=self.instance_sg,
            role=instance_role,
        )

        asg.add_user_data(f"echo ECS_CLUSTER={self.cluster.cluster_name} >> /etc/ecs/ecs.config")

        capacity_provider = ecs.AsgCapacityProvider(
            self,
            "AsgCapacityProvider",
            auto_scaling_group=asg,
            enable_managed_scaling=True,
            enable_managed_termination_protection=True,
        )
        self.cluster.add_asg_capacity_provider(capacity_provider)
        self.capacity_provider = capacity_provider

        for key, value in self.config["tags"].items():
            Tags.of(asg).add(key, value)

        ecs_config = self.config["ecs"]

        self.log_group = logs.LogGroup(
            self,
            "Ec2TaskLogGroup",
            retention=logs.RetentionDays.ONE_WEEK if self.environment_name == "dev" else logs.RetentionDays.ONE_MONTH,
            removal_policy=RemovalPolicy.DESTROY if self.environment_name == "dev" else RemovalPolicy.RETAIN,
        )

        self.task_definition = ecs.TaskDefinition(
            self,
            "Ec2TaskDefinition",
            family=f"{self.config['project_name']}-task-ec2-{self.environment_name}",
            compatibility=ecs.Compatibility.EC2,
            cpu=str(ecs_config["cpu"]),
            memory_mib=str(ecs_config["memory"]),
            network_mode=ecs.NetworkMode.AWS_VPC,
        )

        ecr_repository_arn = cdk.Fn.import_value(f"cdk-hcm-ecr-{self.environment_name}-repository-arn")
        ecr_repository_name = cdk.Fn.import_value(f"cdk-hcm-ecr-{self.environment_name}-repository-name")

        ecr_repository = ecr.Repository.from_repository_attributes(
            self,
            "ImportedEcrRepositoryEc2",
            repository_arn=ecr_repository_arn,
            repository_name=ecr_repository_name,
        )

        linux_params = ecs.LinuxParameters(self, "LinuxParams")

        self.task_definition.add_container(
            "AppContainer",
            image=ecs.ContainerImage.from_ecr_repository(repository=ecr_repository, tag="7c804ed72ffa98b1a1f94fa1bfba00ab79f9c75a"),
            cpu=ecs_config["cpu"],
            memory_limit_mib=ecs_config["memory"],
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="app",
                log_group=self.log_group,
            ),
            linux_parameters=linux_params,
            privileged=True,
            environment={
                "ENVIRONMENT": self.environment_name,
                "PROJECT_NAME": self.config["project_name"],
                "PYTHONUNBUFFERED": "1",
            },
            port_mappings=[ecs.PortMapping(container_port=8080)],
        )

        self.service = ecs.Ec2Service(
            self,
            "EcsEc2Service",
            cluster=self.cluster,
            task_definition=self.task_definition,
            desired_count=1,
            min_healthy_percent=0,
            max_healthy_percent=100,
            security_groups=[self.task_sg],
            vpc_subnets=ec2.SubnetSelection(subnets=private_subnets),
            enable_execute_command=True,
            capacity_provider_strategies=[
                ecs.CapacityProviderStrategy(
                    capacity_provider=self.capacity_provider.capacity_provider_name,
                    base=1,
                    weight=1,
                )
            ],
            circuit_breaker=ecs.DeploymentCircuitBreaker(rollback=True),
            placement_strategies=[
                ecs.PlacementStrategy.spread_across(ecs.BuiltInAttributes.AVAILABILITY_ZONE)
            ],
        )

        CfnOutput(
            self,
            "Ec2ClusterName",
            value=self.cluster.cluster_name,
            description=f"ECS EC2 Cluster name for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-ec2-{self.environment_name}-cluster-name",
        )

        CfnOutput(
            self,
            "Ec2ClusterArn",
            value=self.cluster.cluster_arn,
            description=f"ECS EC2 Cluster ARN for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-ec2-{self.environment_name}-cluster-arn",
        )

        CfnOutput(
            self,
            "Ec2ServiceName",
            value=self.service.service_name,
            description=f"ECS EC2 Service name for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-ec2-{self.environment_name}-service-name",
        )

        CfnOutput(
            self,
            "Ec2ServiceArn",
            value=self.service.service_arn,
            description=f"ECS EC2 Service ARN for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-ec2-{self.environment_name}-service-arn",
        )

        CfnOutput(
            self,
            "Ec2TaskDefinitionArn",
            value=self.task_definition.task_definition_arn,
            description=f"ECS EC2 Task Definition ARN (privileged) for {self.environment_name}",
            export_name=f"cdk-hcm-ecs-ec2-{self.environment_name}-task-definition-arn",
        )
