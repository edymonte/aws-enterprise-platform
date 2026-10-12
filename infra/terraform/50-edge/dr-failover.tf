# Route 53 DR lab (optional) — DNS-level failover with a health check.
#
#   portal-dr.aws.edymonte.com.br
#     PRIMARY   → CloudFront (healthy while /api/products answers 2xx/3xx)
#     SECONDARY → static maintenance page (S3 website in another region)
#
# Why S3 *website* (public) and not CloudFront + OAC? A second CloudFront
# distribution cannot share the alias with the primary one. The public bucket
# needs an account-level exception (20-governance allow_public_s3_website=true)
# and AWS Config will flag it — both are part of the lesson (ADR-0005).

resource "aws_s3_bucket" "maintenance" {
  count         = var.enable_dr_lab ? 1 : 0
  provider      = aws.dr
  bucket        = local.dr_fqdn # S3 website + Route 53 alias require bucket name == host name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "maintenance" {
  count                   = var.enable_dr_lab ? 1 : 0
  provider                = aws.dr
  bucket                  = aws_s3_bucket.maintenance[0].id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "maintenance" {
  count    = var.enable_dr_lab ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.maintenance[0].id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "maintenance" {
  count        = var.enable_dr_lab ? 1 : 0
  provider     = aws.dr
  bucket       = aws_s3_bucket.maintenance[0].id
  key          = "index.html"
  content_type = "text/html"
  content      = <<-HTML
    <!doctype html><html lang="en"><head><meta charset="utf-8"><title>MFS — maintenance</title></head>
    <body style="font-family:system-ui;max-width:640px;margin:48px auto;padding:0 16px">
    <h1>Monteiro Financial Services</h1>
    <p>We are switching to our contingency site (${var.dr_region}). Please try again in a few minutes.</p>
    </body></html>
  HTML
}

data "aws_iam_policy_document" "maintenance" {
  count = var.enable_dr_lab ? 1 : 0
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.maintenance[0].arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "maintenance" {
  count      = var.enable_dr_lab ? 1 : 0
  provider   = aws.dr
  bucket     = aws_s3_bucket.maintenance[0].id
  policy     = data.aws_iam_policy_document.maintenance[0].json
  depends_on = [aws_s3_bucket_public_access_block.maintenance]
}

resource "aws_route53_health_check" "primary" {
  count             = var.enable_dr_lab ? 1 : 0
  fqdn              = local.fqdns["prod"]
  type              = "HTTPS"
  port              = 443
  resource_path     = "/api/products"
  failure_threshold = 2
  request_interval  = 30
  tags              = { Name = "hc-portal-prod" }
}

resource "aws_route53_record" "dr_primary" {
  count           = var.enable_dr_lab ? 1 : 0
  zone_id         = data.aws_route53_zone.public.zone_id
  name            = local.dr_fqdn
  type            = "A"
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary[0].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.portal.domain_name
    zone_id                = aws_cloudfront_distribution.portal.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "dr_secondary" {
  count          = var.enable_dr_lab ? 1 : 0
  zone_id        = data.aws_route53_zone.public.zone_id
  name           = local.dr_fqdn
  type           = "A"
  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_s3_bucket_website_configuration.maintenance[0].website_domain
    zone_id                = aws_s3_bucket.maintenance[0].hosted_zone_id
    evaluate_target_health = false
  }
}
