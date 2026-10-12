output "region" {
  value = var.region
}

output "account_id" {
  value = local.account_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "ecr_repository_urls" {
  value = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "ecr_registry" {
  value = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "alb_security_group_id" {
  description = "Goes into gitops/envs/*/platform.values.yaml (ingress.securityGroupId)."
  value       = aws_security_group.alb.id
}

output "alb_name" {
  description = "Deterministic ALB name set by the Ingress annotation; 50-edge looks it up."
  value       = "alb-${local.name}"
}

output "vpc_cidr" {
  value = local.network.vpc_cidr
}

output "db_address" {
  value = local.data_layer.db_address
}

output "db_master_secret_arn" {
  value = local.data_layer.db_master_secret_arn
}

output "banner_secret_name" {
  value = local.data_layer.banner_secret_name
}

output "datadog_secret_name" {
  value = local.data_layer.datadog_secret_name
}
