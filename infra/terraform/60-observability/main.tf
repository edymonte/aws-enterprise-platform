# 60-observability — Amazon Managed Service for Prometheus (AMP).
#
#   pods /metrics ──(managed collector, agentless)──► AMP workspace
#                                                        │ rule groups (PromQL)
#                                                        ▼
#                                         Alertmanager ──► SNS ──► e-mail
#   Grafana (in-cluster, Argo CD) ──SigV4 via Pod Identity──► AMP query API

locals {
  network = data.terraform_remote_state.network.outputs
  eks     = data.terraform_remote_state.eks.outputs
  name    = "${var.org}-${var.environment}"
}

resource "aws_prometheus_workspace" "this" {
  alias = "amp-${local.name}"
}

# ---------------------------------------------------------------------------
# Managed collector (scraper) — no Prometheus agent to run in the cluster
# ---------------------------------------------------------------------------
resource "aws_prometheus_scraper" "eks" {
  alias                = "scraper-${local.name}"
  scrape_configuration = file("${path.module}/../../../observability/amp-scraper-config.yaml")

  source {
    eks {
      cluster_arn        = local.eks.cluster_arn
      subnet_ids         = local.network.private_subnet_ids
      security_group_ids = [local.eks.cluster_security_group_id]
    }
  }

  destination {
    amp {
      workspace_arn = aws_prometheus_workspace.this.arn
    }
  }
}

# The collector authenticates to Kubernetes as user "aps-collector-user";
# the ClusterRole/Binding for that user is delivered by Argo CD.
resource "aws_eks_access_entry" "scraper" {
  cluster_name      = local.eks.cluster_name
  principal_arn     = aws_prometheus_scraper.eks.role_arn
  kubernetes_groups = []
  user_name         = "aps-collector-user"
}

# ---------------------------------------------------------------------------
# Alert rules + Alertmanager → SNS
# ---------------------------------------------------------------------------
resource "aws_prometheus_rule_group_namespace" "portal" {
  name         = "customer-portal"
  workspace_id = aws_prometheus_workspace.this.id
  data         = file("${path.module}/../../../observability/amp-alert-rules.yaml")
}

resource "aws_prometheus_alert_manager_definition" "this" {
  workspace_id = aws_prometheus_workspace.this.id
  definition   = <<-YAML
    alertmanager_config: |
      route:
        receiver: sns
        group_by: ['alertname', 'namespace']
        repeat_interval: 1h
      receivers:
        - name: sns
          sns_configs:
            - topic_arn: ${local.network.alerts_topic_arn}
              sigv4:
                region: ${var.region}
              attributes:
                source: amp
  YAML
}

# ---------------------------------------------------------------------------
# Grafana runs in the cluster (Argo CD); Pod Identity gives it AMP query access.
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

resource "aws_iam_role" "grafana" {
  name               = "${local.name}-grafana"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "grafana" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"
}

resource "aws_eks_pod_identity_association" "grafana" {
  cluster_name    = local.eks.cluster_name
  namespace       = "grafana"
  service_account = "grafana"
  role_arn        = aws_iam_role.grafana.arn
}
