# Phase 04 — Governance: Config, GuardDuty, Security Hub (4 h)

📘 **SAA-C03:** D1 (detective vs preventive controls, encryption defaults)

## 🎯 Goal

Detect misconfiguration (AWS Config), detect threats (GuardDuty), aggregate posture (Security Hub), and turn on cheap preventive account settings.

## 🧠 Concepts

| Control type | AWS service in this lab | Azure equivalent |
|---|---|---|
| **Preventive** (stop it) | S3 account public access block, EBS encryption by default, IAM permissions boundary; *SCPs in an Organization* | Azure Policy `Deny` |
| **Detective** (see it) | AWS Config managed rules + **custom Guard rule** | Azure Policy `Audit` |
| **Threat detection** | GuardDuty (incl. EKS audit logs + runtime monitoring) | Defender for Cloud |
| **Posture aggregation** | Security Hub (AWS FSBP standard) | Defender secure score |
| **Access review** | IAM Access Analyzer | — |

The custom rule `infra/policies/rds-iam-auth-enabled.guard` is **policy as code** in AWS: a CloudFormation Guard rule evaluated by Config on every RDS configuration change.

## 🛠️ Steps

1. Read `20-governance/main.tf`; note the Config recorder records **only** the resource types we govern (cost control).
2. `./scripts/awp.ps1 apply 20-governance`
3. After phases 05–06 exist, check compliance:

```powershell
aws configservice describe-compliance-by-config-rule --query "ComplianceByConfigRules[].{rule:ConfigRuleName,state:Compliance.ComplianceType}" --output table
```

Expected: `eks-endpoint-no-public-access` is **NON_COMPLIANT** (the API endpoint is public, allow-listed). That is a *documented exception*, not a bug — explain why in the ADR you write in phase 14.

## ✅ Checkpoint

- [ ] Recorder `RECORDING`; 8 rules evaluated.
- [ ] GuardDuty detector enabled with EKS features; Security Hub shows the FSBP score.

## 💥 Break it

Try `aws s3api put-bucket-policy` making any bucket public. **Observation:** `AccessDenied ... BlockPublicPolicy`. **Evidence:** `aws s3control get-public-access-block --account-id <id>`. **Lesson:** the account-level block wins over bucket settings — the reason the DR lab in phase 10 needs an explicit exception.

## 🏋️ Challenge — auto-remediation

Add automatic remediation for `s3-bucket-public-read-prohibited` using the SSM document `AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock`.

<details><summary>Answer</summary>

```hcl
resource "aws_config_remediation_configuration" "s3_public" {
  config_rule_name = aws_config_config_rule.managed["s3-bucket-public-read-prohibited"].name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock"
  automatic        = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60

  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }
  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation.arn   # role with s3:PutBucketPublicAccessBlock
  }
}
```

This is AWS's version of Azure Policy `DeployIfNotExists/Modify`.

</details>

## 🎤 Interview

1. Preventive vs detective controls — give two AWS examples of each.
2. What is an SCP and why doesn't it apply to the management account?
3. GuardDuty vs Security Hub vs Inspector vs Config?
4. How would you roll out a new guardrail without breaking teams?
