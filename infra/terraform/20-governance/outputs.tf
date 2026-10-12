output "config_rule_names" {
  value = concat([for r in aws_config_config_rule.managed : r.name], [aws_config_config_rule.rds_iam_auth.name])
}

output "guardduty_detector_id" {
  value = try(aws_guardduty_detector.this[0].id, null)
}
