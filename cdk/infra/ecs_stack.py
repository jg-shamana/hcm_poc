from typing import Dict, Any
from constructs import Construct
import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ecs as ecs,
    aws_ec2 as ec2,
    aws_ecr as ecr,
    aws_servicediscovery as sd,
    aws_iam as iam,
    aws_logs as logs,
    aws_secretsmanager as secretsmanager,
    CfnOutput,
    Tags,
    RemovalPolicy
)

class EcsStack(Stack):

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
        
        self.security_group = self._create_security_group()
        
        self.cluster = self._create_ecs_cluster()
        
        self.newrelic_secret = secretsmanager.Secret.from_secret_name_v2(
            self,
            "NewRelicSecret",
            secret_name="hcm_poc"
        )
        
        self.task_role = self._create_task_role()
        self.execution_role = self._create_execution_role()
        
        self.execution_role.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
                resources=[self.newrelic_secret.secret_arn]
            )
        )
        
        self.log_group = self._create_log_group()
        self.firelens_log_group = self._create_firelens_log_group()
        
        self.task_definition = self._create_task_definition()
        
        self.service = self._create_ecs_service()
        
        self._create_outputs()

    def _import_vpc(self) -> ec2.IVpc:
        return ec2.Vpc.from_vpc_attributes(
            self,
            "ImportedVpc",
            vpc_id=cdk.Fn.import_value(f"cdk-hcm-vpc-{self.environment_name}-vpc-id"),
            availability_zones=[
                cdk.Fn.select(0, cdk.Fn.get_azs()),
                cdk.Fn.select(1, cdk.Fn.get_azs())
            ]
        )

    def _create_security_group(self) -> ec2.SecurityGroup:
        sg = ec2.SecurityGroup(
            self,
            "EcsSecurityGroup",
            vpc=self.vpc,
            description=f"Security group for ECS tasks in {self.environment_name} environment",
            allow_all_outbound=True
        )

        for key, value in self.config["tags"].items():
            Tags.of(sg).add(key, value)

        Tags.of(sg).add("Name", f"{self.config['project_name']}-ecs-sg-{self.environment_name}")

        return sg

    def _create_ecs_cluster(self) -> ecs.Cluster:
        cluster = ecs.Cluster(
            self,
            "EcsCluster",
            vpc=self.vpc,
            cluster_name=f"{self.config['project_name']}-cluster-{self.environment_name}",
            container_insights=True
        )

        cm = self.config.get("cloudmap", {})
        ns_id_export = cm.get("namespace_id_export_name")
        ns_arn_export = cm.get("namespace_arn_export_name")
        ns_name = cm.get("namespace_name")
        if ns_id_export and ns_arn_export and ns_name:
            namespace_id = cdk.Fn.import_value(ns_id_export)
            namespace_arn = cdk.Fn.import_value(ns_arn_export)
            self.cloud_map_namespace = sd.PrivateDnsNamespace.from_private_dns_namespace_attributes(
                self,
                "ImportedCloudMapNamespace",
                namespace_id=namespace_id,
                namespace_arn=namespace_arn,
                namespace_name=ns_name
            )

        return cluster

    def _create_task_role(self) -> iam.Role:
        return iam.Role(
            self,
            "EcsTaskRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            description=f"IAM role for ECS tasks in {self.environment_name} environment",
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonECSTaskExecutionRolePolicy")
            ]
        )

    def _create_execution_role(self) -> iam.Role:
        role = iam.Role(
            self,
            "EcsExecutionRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            description=f"IAM execution role for ECS tasks in {self.environment_name} environment"
        )

        role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonECSTaskExecutionRolePolicy")
        )

        role.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                resources=[f"arn:aws:logs:{self.region}:{self.account}:log-group:/ecs/*"]
            )
        )

        return role

    def _create_log_group(self) -> logs.LogGroup:
        return logs.LogGroup(
            self,
            "EcsLogGroup",
            log_group_name=f"/ecs/{self.config['project_name']}-{self.environment_name}",
            retention=logs.RetentionDays.ONE_WEEK if self.environment_name == "dev" else logs.RetentionDays.ONE_MONTH,
            removal_policy=RemovalPolicy.DESTROY if self.environment_name == "dev" else RemovalPolicy.RETAIN
        )

    def _create_firelens_log_group(self) -> logs.LogGroup:
        return logs.LogGroup(
            self,
            "FirelensLogGroup",
            log_group_name=f"/ecs/{self.config['project_name']}-firelens-{self.environment_name}",
            retention=logs.RetentionDays.ONE_WEEK if self.environment_name == "dev" else logs.RetentionDays.ONE_MONTH,
            removal_policy=RemovalPolicy.DESTROY if self.environment_name == "dev" else RemovalPolicy.RETAIN
        )

    def _create_task_definition(self) -> ecs.FargateTaskDefinition:
        ecs_config = self.config["ecs"]
        
        task_definition = ecs.FargateTaskDefinition(
            self,
            "TaskDefinition",
            family=f"{self.config['project_name']}-task-{self.environment_name}",
            cpu=ecs_config["cpu"],
            memory_limit_mib=ecs_config["memory"],
            task_role=self.task_role,
            execution_role=self.execution_role
        )

        ecr_repository_arn = cdk.Fn.import_value(f"cdk-hcm-ecr-{self.environment_name}-repository-arn")
        ecr_repository_name = cdk.Fn.import_value(f"cdk-hcm-ecr-{self.environment_name}-repository-name")
        
        ecr_repository = ecr.Repository.from_repository_attributes(
            self,
            "ImportedEcrRepository",
            repository_arn=ecr_repository_arn,
            repository_name=ecr_repository_name
        )

        firelens_container = task_definition.add_firelens_log_router(
            "log_router",
            image=ecs.ContainerImage.from_registry("533243300146.dkr.ecr.ap-northeast-1.amazonaws.com/newrelic/logging-firelens-fluentbit"),
            firelens_config=ecs.FirelensConfig(
                type=ecs.FirelensLogRouterType.FLUENTBIT,
                options=ecs.FirelensOptions(enable_ecs_log_metadata=True)
            ),
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="firelens",
                log_group=self.firelens_log_group
            ),
            cpu=50,
            memory_reservation_mib=50,
            environment={
                "AWS_REGION": self.region
            }
        )

        json_key = f"hcm-poc-{self.environment_name}-newrelic-api-key"

        app_container = task_definition.add_container(
            "AppContainer",
            image=ecs.ContainerImage.from_ecr_repository(repository=ecr_repository, tag="latest"),
            cpu=ecs_config["cpu"] - 50,
            memory_limit_mib=ecs_config["memory"] - 50,
            logging=ecs.LogDrivers.firelens(
                options={
                    "Name": "newrelic",
                    "endpoint": "https://log-api.newrelic.com/log/v1",
                    "log_type": "application"
                },
                secret_options={
                    "apiKey": ecs.Secret.from_secrets_manager(self.newrelic_secret, field=json_key)
                }
            ),
            environment={
                "ENVIRONMENT": self.environment_name,
                "PROJECT_NAME": self.config["project_name"],
                "PYTHONUNBUFFERED": "1"
            }
        )
        
        for key, value in self.config["tags"].items():
            Tags.of(task_definition).add(key, value)
        
        return task_definition

    def _create_ecs_service(self) -> ecs.FargateService:
        ecs_config = self.config["ecs"]
        
        private_subnets = []
        for i in range(2):
            subnet_id = cdk.Fn.import_value(f"cdk-hcm-vpc-{self.environment_name}-private-subnet-{i+1}-id")
            subnet = ec2.Subnet.from_subnet_id(
                self,
                f"PrivateSubnet{i+1}",
                subnet_id
            )
            private_subnets.append(subnet)
        
        service = ecs.FargateService(
            self,
            "EcsService",
            cluster=self.cluster,
            task_definition=self.task_definition,
            service_name=f"{self.config['project_name']}-service-{self.environment_name}",
            desired_count=ecs_config["desired_count"],
            max_healthy_percent=200,
            min_healthy_percent=50,
            vpc_subnets=ec2.SubnetSelection(subnets=private_subnets),
            security_groups=[self.security_group],
            assign_public_ip=False,
            platform_version=ecs.FargatePlatformVersion.LATEST,
            enable_execute_command=True,
            cloud_map_options=ecs.CloudMapOptions(
                name="app",
                dns_record_type=sd.DnsRecordType.A,
                dns_ttl=cdk.Duration.seconds(30),
                cloud_map_namespace=getattr(self, "cloud_map_namespace", None)
            )
        )
        
        for key, value in self.config["tags"].items():
            Tags.of(service).add(key, value)
        
        return service

    def _create_outputs(self) -> None:
        CfnOutput(
            self,
            "ClusterName",
            value=self.cluster.cluster_name,
            description=f"ECS Cluster name for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-{self.environment_name}-cluster-name"
        )

        CfnOutput(
            self,
            "ClusterArn",
            value=self.cluster.cluster_arn,
            description=f"ECS Cluster ARN for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-{self.environment_name}-cluster-arn"
        )

        CfnOutput(
            self,
            "ServiceName",
            value=self.service.service_name,
            description=f"ECS Service name for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-{self.environment_name}-service-name"
        )

        CfnOutput(
            self,
            "ServiceArn",
            value=self.service.service_arn,
            description=f"ECS Service ARN for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-{self.environment_name}-service-arn"
        )

        CfnOutput(
            self,
            "TaskDefinitionArn",
            value=self.task_definition.task_definition_arn,
            description=f"ECS Task Definition ARN for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-{self.environment_name}-task-definition-arn"
        )

        CfnOutput(
            self,
            "LogGroupName",
            value=self.log_group.log_group_name,
            description=f"CloudWatch Log Group name for {self.environment_name} environment",
            export_name=f"cdk-hcm-ecs-{self.environment_name}-log-group-name"
        ) 
