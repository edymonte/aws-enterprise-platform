# 05-identity — WHO may change the platform.
#
# Creates, with Terraform instead of console clicks:
#   1. IAM OIDC identity providers for GitHub Actions and (optionally) Azure DevOps.
#   2. IAM roles the pipelines ASSUME with short-lived credentials (no access keys):
#        - plan role   : read-only + state access   (any pull request)
#        - deploy role : admin bounded by a permissions boundary (environment 'lab' only)
#   3. A permissions boundary that blocks the classic escalation/persistence paths.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  state_arn  = "arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}"

  # Trust: which token subjects may assume each role.
  github_plan_subjects   = ["repo:${var.github_repository}:pull_request"]
  github_deploy_subjects = ["repo:${var.github_repository}:environment:lab"]
}

# ---------------------------------------------------------------------------
# OIDC identity providers
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_openid_connect_provider" "ado" {
  count          = var.ado_organization_id != "" ? 1 : 0
  url            = "https://vstoken.dev.azure.com/${var.ado_organization_id}"
  client_id_list = ["api://AzureADTokenExchange"]
}

# ---------------------------------------------------------------------------
# Permissions boundary: the deploy role can build the platform, but cannot
# create long-lived credentials, touch billing/org settings, or remove its
# own boundary.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "AllowEverythingByDefault"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    sid    = "DenyLongLivedCredentials"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyAccountAndOrgChanges"
    effect    = "Deny"
    actions   = ["organizations:*", "account:*", "aws-portal:*", "billing:*"]
    resources = ["*"]
  }

  statement {
    sid    = "DenyBoundaryTampering"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${local.account_id}:policy/${var.org}-pipeline-boundary"]
  }
}

resource "aws_iam_policy" "boundary" {
  name   = "${var.org}-pipeline-boundary"
  policy = data.aws_iam_policy_document.boundary.json
}

# ---------------------------------------------------------------------------
# Terraform state access (needed by both roles; plan writes the .tflock file)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "state" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/*"]
  }
}

resource "aws_iam_policy" "state" {
  name   = "${var.org}-terraform-state"
  policy = data.aws_iam_policy_document.state.json
}

# ---------------------------------------------------------------------------
# GitHub Actions roles
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "github_trust" {
  for_each = {
    plan   = local.github_plan_subjects
    deploy = local.github_deploy_subjects
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value
    }
  }
}

resource "aws_iam_role" "github" {
  for_each             = data.aws_iam_policy_document.github_trust
  name                 = "${var.org}-github-${each.key}"
  assume_role_policy   = each.value.json
  max_session_duration = 3600
  permissions_boundary = aws_iam_policy.boundary.arn
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github["plan"].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "github_deploy_admin" {
  role       = aws_iam_role.github["deploy"].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "github_state" {
  for_each   = aws_iam_role.github
  role       = each.value.name
  policy_arn = aws_iam_policy.state.arn
}

# ---------------------------------------------------------------------------
# Azure DevOps role (AWS Toolkit for Azure DevOps, OIDC service connection)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ado_trust" {
  count = var.ado_organization_id != "" ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ado[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "vstoken.dev.azure.com/${var.ado_organization_id}:aud"
      values   = ["api://AzureADTokenExchange"]
    }
    condition {
      test     = "StringEquals"
      variable = "vstoken.dev.azure.com/${var.ado_organization_id}:sub"
      values   = [var.ado_service_connection_subject]
    }
  }
}

resource "aws_iam_role" "ado" {
  count                = var.ado_organization_id != "" ? 1 : 0
  name                 = "${var.org}-azure-devops-deploy"
  assume_role_policy   = data.aws_iam_policy_document.ado_trust[0].json
  permissions_boundary = aws_iam_policy.boundary.arn
}

resource "aws_iam_role_policy_attachment" "ado_admin" {
  count      = var.ado_organization_id != "" ? 1 : 0
  role       = aws_iam_role.ado[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "ado_state" {
  count      = var.ado_organization_id != "" ? 1 : 0
  role       = aws_iam_role.ado[0].name
  policy_arn = aws_iam_policy.state.arn
}
