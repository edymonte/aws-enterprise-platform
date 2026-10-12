# 20-governance — detective + preventive guardrails for the account.
#
# Azure → AWS mental map:
#   Azure Policy (Audit)   ≈ AWS Config rules (detective)
#   Azure Policy (Deny)    ≈ SCPs (needs AWS Organizations) / account-level blocks / IAM boundaries
#   Defender for Cloud     ≈ GuardDuty (threats) + Security Hub (posture) + Inspector (vulns)

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name = "${var.org}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Preventive, account-wide settings (cheap and effective)
# ---------------------------------------------------------------------------
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = !var.allow_public_s3_website # exception needed only by the DR lab (phase 10)
  restrict_public_buckets = !var.allow_public_s3_website
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "${local.name}-access-analyzer"
  type          = "ACCOUNT"
}

# ---------------------------------------------------------------------------
# AWS Config: recorder limited to the resource types we govern (cost control)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "config" {
  bucket        = "${var.org}-config-${data.aws_caller_identity.current.account_id}-${var.name_suffix}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "config_bucket" {
  statement {
    sid       = "AWSConfigBucketPermissionsCheck"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [aws_s3_bucket.config.arn]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
  statement {
    sid       = "AWSConfigBucketDelivery"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = data.aws_iam_policy_document.config_bucket.json
}

resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${local.name}-recorder"
  role_arn = aws_iam_service_linked_role.config.arn

  recording_group {
    all_supported = false
    resource_types = [
      "AWS::EC2::SecurityGroup",
      "AWS::EC2::VPC",
      "AWS::S3::Bucket",
      "AWS::RDS::DBInstance",
      "AWS::EKS::Cluster",
      "AWS::IAM::Role",
    ]
    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${local.name}-delivery"
  s3_bucket_name = aws_s3_bucket.config.bucket
  depends_on     = [aws_config_configuration_recorder.this, aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# Managed rules: identifier => input parameters
locals {
  managed_rules = {
    "s3-bucket-public-read-prohibited" = { id = "S3_BUCKET_PUBLIC_READ_PROHIBITED", params = null }
    "rds-instance-public-access-check" = { id = "RDS_INSTANCE_PUBLIC_ACCESS_CHECK", params = null }
    "rds-storage-encrypted"            = { id = "RDS_STORAGE_ENCRYPTED", params = null }
    "eks-endpoint-no-public-access"    = { id = "EKS_ENDPOINT_NO_PUBLIC_ACCESS", params = null }
    "vpc-flow-logs-enabled"            = { id = "VPC_FLOW_LOGS_ENABLED", params = null }
    "restricted-ssh"                   = { id = "INCOMING_SSH_DISABLED", params = null }
    "required-tags" = {
      id = "REQUIRED_TAGS"
      params = jsonencode({
        tag1Key = "Owner"
        tag2Key = "Environment"
        tag3Key = "CostCenter"
      })
    }
  }
}

resource "aws_config_config_rule" "managed" {
  for_each         = local.managed_rules
  name             = "${local.name}-${each.key}"
  input_parameters = each.value.params

  source {
    owner             = "AWS"
    source_identifier = each.value.id
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# Custom rule written in Guard (policy as code, file in /infra/policies)
resource "aws_config_config_rule" "rds_iam_auth" {
  name = "${local.name}-rds-iam-auth-enabled"

  scope {
    compliance_resource_types = ["AWS::RDS::DBInstance"]
  }

  source {
    owner = "CUSTOM_POLICY"

    source_detail {
      message_type = "ConfigurationItemChangeNotification"
    }

    custom_policy_details {
      policy_runtime = "guard-2.x.x"
      policy_text    = file("${path.module}/../../policies/rds-iam-auth-enabled.guard")
    }
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

# ---------------------------------------------------------------------------
# Threat detection and posture (30-day trials on new accounts)
# ---------------------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  count  = var.enable_threat_detection ? 1 : 0
  enable = true
}

resource "aws_guardduty_detector_feature" "eks_audit" {
  count       = var.enable_threat_detection ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "runtime" {
  count       = var.enable_threat_detection ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}

resource "aws_securityhub_account" "this" {
  count                    = var.enable_threat_detection ? 1 : 0
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  count         = var.enable_threat_detection ? 1 : 0
  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}
