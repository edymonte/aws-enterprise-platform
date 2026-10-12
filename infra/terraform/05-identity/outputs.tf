output "github_plan_role_arn" {
  description = "GitHub repo variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.github["plan"].arn
}

output "github_deploy_role_arn" {
  description = "GitHub repo variable AWS_DEPLOY_ROLE_ARN."
  value       = aws_iam_role.github["deploy"].arn
}

output "ado_role_arn" {
  description = "Role ARN for the AWS service connection in Azure DevOps (OIDC)."
  value       = try(aws_iam_role.ado[0].arn, null)
}

output "pipeline_boundary_arn" {
  value = aws_iam_policy.boundary.arn
}
