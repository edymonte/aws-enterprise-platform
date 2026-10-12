output "db_address" {
  value = aws_db_instance.portal.address
}

output "db_port" {
  value = aws_db_instance.portal.port
}

output "db_name" {
  value = aws_db_instance.portal.db_name
}

output "db_resource_id" {
  description = "Used in the rds-db:connect IAM resource ARN."
  value       = aws_db_instance.portal.resource_id
}

output "db_master_secret_arn" {
  value = aws_db_instance.portal.master_user_secret[0].secret_arn
}

output "banner_secret_name" {
  value = aws_secretsmanager_secret.banner.name
}

output "banner_secret_arn" {
  value = aws_secretsmanager_secret.banner.arn
}

output "datadog_secret_name" {
  value = aws_secretsmanager_secret.datadog.name
}
