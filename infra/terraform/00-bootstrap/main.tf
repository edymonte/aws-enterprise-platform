# 00-bootstrap — long-lived resources that survive the daily destroy cycle.
#
# Uses LOCAL state on purpose (chicken-and-egg: it creates the remote state
# bucket). Run once at the beginning of the lab; destroy only at the very end.

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      Environment = "shared"
      Layer       = "00-bootstrap"
    })
  }
}

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# ---------------------------------------------------------------------------
# Terraform remote state: versioned, encrypted, private, TLS-only.
# Locking: S3 native lock files (backend use_lockfile = true, Terraform >= 1.10).
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.org}-tfstate-${data.aws_caller_identity.current.account_id}-${random_string.suffix.result}"
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    object_ownership = "BucketOwnerEnforced" # ACLs disabled
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

data "aws_iam_policy_document" "tfstate" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate.json
}

# ---------------------------------------------------------------------------
# Public hosted zone for the AWS side of the domain (aws.edymonte.com.br).
# The parent zone (Azure DNS or Registro.br) delegates it with NS records.
# ---------------------------------------------------------------------------
resource "aws_route53_zone" "public" {
  count = var.public_zone_name == "" ? 0 : 1
  name  = var.public_zone_name
}

# ---------------------------------------------------------------------------
# Cost guardrail — the first control a real platform team puts in place.
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "lab" {
  count        = var.enable_budget ? 1 : 0
  name         = "${var.org}-aws-lab"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [
      { threshold = 50, type = "ACTUAL" },
      { threshold = 80, type = "ACTUAL" },
      { threshold = 100, type = "FORECASTED" },
    ]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = [var.alert_email]
    }
  }
}
