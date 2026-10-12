# 10-network — VPC across 2 AZs, NAT, VPC endpoints, flow logs, alert topic.
#
# Uses the community module terraform-aws-modules/vpc — what most consulting
# teams use in practice. Read the module's inputs: they map 1:1 to the AWS
# concepts (public/private/database subnets, route tables, NAT).

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.org}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "vpc-${local.name}"
  cidr = var.vpc_cidr
  azs  = local.azs

  # /20 private subnets: with the VPC CNI every POD takes a VPC IP — size for pods, not nodes.
  private_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets   = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, 100 + i)]
  database_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, 110 + i)]

  create_database_subnet_group       = true
  create_database_subnet_route_table = true # no route to the internet at all

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway # lab: 1 NAT; production: one per AZ
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnet discovery tags used by the AWS Load Balancer Controller
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = 7
}

# Gateway endpoint for S3 is FREE and keeps ECR layer downloads off the NAT.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
  tags              = { Name = "vpce-s3-${local.name}" }
}

# Interface endpoints cost per AZ-hour: off by default, a phase 03 exercise.
resource "aws_security_group" "endpoints" {
  count       = var.enable_interface_endpoints ? 1 : 0
  name        = "sg-vpce-${local.name}"
  description = "HTTPS from inside the VPC to interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = var.enable_interface_endpoints ? toset(["ecr.api", "ecr.dkr", "sts", "logs", "secretsmanager"]) : toset([])
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true
  tags                = { Name = "vpce-${each.value}-${local.name}" }
}

# ---------------------------------------------------------------------------
# Shared alert sink (Budgets, CloudWatch alarms, Prometheus Alertmanager)
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-platform-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "AllowAWSServicesToPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["aps.amazonaws.com", "cloudwatch.amazonaws.com", "budgets.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}
