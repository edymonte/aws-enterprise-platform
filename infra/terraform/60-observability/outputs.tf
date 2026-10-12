output "amp_workspace_id" {
  value = aws_prometheus_workspace.this.id
}

output "amp_query_endpoint" {
  description = "Grafana data source URL (gitops/platform/grafana/values.yaml)."
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}

output "scraper_role_arn" {
  value = aws_prometheus_scraper.eks.role_arn
}
