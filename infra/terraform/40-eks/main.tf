# 40-eks — EKS platform for the customer portal.
#
# Cluster access: EKS access entries (API mode) — no aws-auth ConfigMap.
# Workload identity: EKS Pod Identity — no IRSA annotations, no secrets.
# Delivery: GitOps (Argo CD) — CI pipelines never talk to the cluster.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  network    = data.terraform_remote_state.network.outputs
  data_layer = data.terraform_remote_state.data.outputs
  name       = "${var.org}-portal-${var.environment}"
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id

  # Kubernetes namespaces that host the portal (one per GitOps environment)
  portal_namespaces = ["portal-dev", "portal-prod"]
}

# ---------------------------------------------------------------------------
# EKS cluster + managed node group
# ---------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "eks-${local.name}"
  kubernetes_version = var.kubernetes_version

  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = local.network.operator_ip_ranges

  vpc_id     = local.network.vpc_id
  subnet_ids = local.network.private_subnet_ids

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.extra_admin_access_entries

  enabled_log_types = ["audit", "authenticator"]

  addons = {
    vpc-cni = {
      before_compute       = true
      configuration_values = jsonencode({ enableNetworkPolicy = "true" })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    coredns    = {}
    kube-proxy = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]
      capacity_type  = var.node_capacity_type
      min_size       = 1
      max_size       = 3
      desired_size   = var.node_desired_size
    }
  }
}

# CloudWatch Container Insights (logs + metrics) via the managed add-on.
resource "aws_eks_addon" "cloudwatch" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  pod_identity_association {
    role_arn        = aws_iam_role.pod["cloudwatch"].arn
    service_account = "cloudwatch-agent"
  }
}

# ---------------------------------------------------------------------------
# Container registries (immutable tags + scan on push)
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  for_each             = toset(["customer-portal-api", "customer-portal-web"])
  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # lab: allow the daily destroy

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 15 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 15 }
      action       = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------
# EKS Pod Identity roles (trust: pods.eks.amazonaws.com)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pod" {
  for_each           = toset(["portal-api", "load-balancer-controller", "cloudwatch"])
  name               = "${local.name}-${each.value}"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

# Portal API: IAM DB auth for ONE database user + read ONE secret.
data "aws_iam_policy_document" "portal_api" {
  statement {
    sid       = "ConnectAsPortalApiUser"
    actions   = ["rds-db:connect"]
    resources = ["arn:${local.partition}:rds-db:${var.region}:${local.account_id}:dbuser:${local.data_layer.db_resource_id}/portal_api"]
  }
  statement {
    sid       = "ReadBannerSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [local.data_layer.banner_secret_arn]
  }
}

resource "aws_iam_role_policy" "portal_api" {
  name   = "portal-api"
  role   = aws_iam_role.pod["portal-api"].id
  policy = data.aws_iam_policy_document.portal_api.json
}

resource "aws_eks_pod_identity_association" "portal_api" {
  for_each        = toset(local.portal_namespaces)
  cluster_name    = module.eks.cluster_name
  namespace       = each.value
  service_account = "customer-portal-api"
  role_arn        = aws_iam_role.pod["portal-api"].arn
}

# AWS Load Balancer Controller (official policy, versioned in /infra/policies)
resource "aws_iam_role_policy" "load_balancer_controller" {
  name   = "aws-load-balancer-controller"
  role   = aws_iam_role.pod["load-balancer-controller"].id
  policy = file("${path.module}/../../policies/aws-load-balancer-controller.json")
}

resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.pod["load-balancer-controller"].arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  for_each   = toset(["CloudWatchAgentServerPolicy", "AWSXrayWriteOnlyAccess"])
  role       = aws_iam_role.pod["cloudwatch"].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value}"
}

# ---------------------------------------------------------------------------
# Security group the ALB uses: HTTP only from CloudFront (+ operator).
# Referenced by the Ingress annotation alb.ingress.kubernetes.io/security-groups.
# ---------------------------------------------------------------------------
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name        = "sg-alb-${local.name}"
  description = "Portal ALB: HTTP from CloudFront origin-facing IPs and the operator only"
  vpc_id      = local.network.vpc_id

  # The CloudFront prefix list counts as ~55 rules against the 60-rule SG quota.
  ingress {
    description     = "CloudFront origin-facing"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  dynamic "ingress" {
    for_each = length(local.network.operator_ip_ranges) > 0 ? [1] : []
    content {
      description = "Operator testing before CloudFront exists"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = local.network.operator_ip_ranges
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
