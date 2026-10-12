# 50-edge — public entry: ACM, CloudFront + WAF, Route 53 records, DR lab.
#
# Azure → AWS mental map:
#   Front Door             ≈ CloudFront
#   Front Door WAF policy  ≈ AWS WAF web ACL (scope CLOUDFRONT)
#   Managed certificate    ≈ ACM certificate (DNS-validated in Route 53)
#   Traffic Manager        ≈ Route 53 routing policies + health checks

locals {
  eks = data.terraform_remote_state.eks.outputs

  # host label => environment. portal.aws.edymonte.com.br, portal-dev.aws.edymonte.com.br
  hosts = {
    prod = var.prod_host_label
    dev  = var.dev_host_label
  }
  fqdns    = { for k, h in local.hosts : k => "${h}.${var.zone_name}" }
  dr_fqdn  = "${var.dr_host_label}.${var.zone_name}"
  all_fqdn = concat(values(local.fqdns), var.enable_dr_lab ? [local.dr_fqdn] : [])
}

data "aws_route53_zone" "public" {
  name = var.zone_name
}

# The ALB is created by the AWS Load Balancer Controller from the Ingress
# (deterministic name via annotation) — Terraform only looks it up.
data "aws_lb" "portal" {
  name = var.alb_name_override != "" ? var.alb_name_override : local.eks.alb_name
}

# ---------------------------------------------------------------------------
# Certificate (us-east-1 for CloudFront), validated through Route 53
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "portal" {
  domain_name               = local.all_fqdn[0]
  subject_alternative_names = slice(local.all_fqdn, 1, length(local.all_fqdn))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for o in aws_acm_certificate.portal.domain_validation_options : o.domain_name => o
  }
  zone_id         = data.aws_route53_zone.public.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "portal" {
  certificate_arn         = aws_acm_certificate.portal.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ---------------------------------------------------------------------------
# WAF — starts in COUNT (observe), BLOCK is a game-day step.
# ---------------------------------------------------------------------------
locals {
  managed_rule_groups = {
    AWSManagedRulesCommonRuleSet         = 10
    AWSManagedRulesKnownBadInputsRuleSet = 20
    AWSManagedRulesSQLiRuleSet           = 30
  }
}

resource "aws_wafv2_web_acl" "portal" {
  name  = "waf-${var.org}-portal-${var.environment}"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.managed_rule_groups
    content {
      name     = rule.key
      priority = rule.value

      override_action {
        dynamic "count" {
          for_each = var.waf_mode == "count" ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = var.waf_mode == "block" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = rule.key
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "RateLimitPerClient"
    priority = 100

    action {
      dynamic "count" {
        for_each = var.waf_mode == "count" ? [1] : []
        content {}
      }
      dynamic "block" {
        for_each = var.waf_mode == "block" ? [1] : []
        content {}
      }
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerClient"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "portal-web-acl"
    sampled_requests_enabled   = true
  }
}

# ---------------------------------------------------------------------------
# CloudFront
# ---------------------------------------------------------------------------
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer" # forwards the Host header, so the ALB can route by host
}

resource "aws_cloudfront_distribution" "portal" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "MFS customer portal (${var.environment})"
  aliases         = local.all_fqdn
  price_class     = "PriceClass_100"
  web_acl_id      = aws_wafv2_web_acl.portal.arn

  origin {
    origin_id   = "alb"
    domain_name = data.aws_lb.portal.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # TLS ends at the edge (see ADR-0005)
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Shared-secret header the origin can verify (phase 10 challenge).
    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_header
    }
  }

  default_cache_behavior {
    target_origin_id         = "alb"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    compress                 = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.portal.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_record" "portal" {
  for_each = local.fqdns
  zone_id  = data.aws_route53_zone.public.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.portal.domain_name
    zone_id                = aws_cloudfront_distribution.portal.hosted_zone_id
    evaluate_target_health = false
  }
}
