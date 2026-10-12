output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.portal.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.portal.id
}

output "portal_urls" {
  value = { for k, f in local.fqdns : k => "https://${f}" }
}

output "dr_url" {
  value = var.enable_dr_lab ? "http://${local.dr_fqdn}" : null
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.portal.arn
}
