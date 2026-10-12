output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.region
}

output "state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "zone_name" {
  value = try(aws_route53_zone.public[0].name, "")
}

output "zone_id" {
  value = try(aws_route53_zone.public[0].zone_id, "")
}

output "zone_name_servers" {
  description = "Create an NS record for the subdomain in the parent zone with these values."
  value       = try(aws_route53_zone.public[0].name_servers, [])
}

output "name_suffix" {
  description = "Stable suffix for globally unique names, so they survive the daily down/up."
  value       = random_string.suffix.result
}
