# Phase 05 — Data: RDS with IAM auth and Secrets Manager (4 h)

📘 **SAA-C03:** D1 (encryption, secrets), D2 (Multi-AZ vs read replicas)

## 🎯 Goal

A private PostgreSQL database the application reaches **without a password**, and a sample secret managed outside Terraform.

## 🧠 Concepts

- **`manage_master_user_password = true`** — RDS generates the master password and stores/rotates it in Secrets Manager. It never appears in Terraform code or state.
- **IAM database authentication** — the app signs a token with its IAM credentials (valid 15 minutes) and uses it as the password; TLS is mandatory. Supported for MySQL/MariaDB/PostgreSQL only.
- **Database subnets** have no route to the internet; the SG only accepts 5432 from the private (pod) subnets.
- **Multi-AZ** (sync standby, failover) is for availability; **read replicas** (async) are for read scaling. Lab: single-AZ for cost.

## 🛠️ Steps

1. `./scripts/awp.ps1 apply 30-data` (RDS takes ~5–10 min).
2. Write the sample secret:

```powershell
$secret = terraform -chdir=infra/terraform/30-data output -raw banner_secret_name
aws secretsmanager put-secret-value --secret-id $secret --secret-string "Welcome to the MFS portal on AWS — v1"
```

3. Look at the master secret (metadata only): `aws secretsmanager describe-secret --secret-id (terraform -chdir=infra/terraform/30-data output -raw db_master_secret_arn)`.

## ✅ Checkpoint

```powershell
aws rds describe-db-instances --db-instance-identifier rds-mfs-portal-lab `
  --query "DBInstances[0].{public:PubliclyAccessible,iam:IAMDatabaseAuthenticationEnabled,encrypted:StorageEncrypted,subnets:DBSubnetGroup.DBSubnetGroupName}"
```

- [ ] `public: false`, `iam: true`, `encrypted: true`.
- [ ] Config custom rule `rds-iam-auth-enabled` → COMPLIANT.

## 💥 Break it

Apply with IAM auth disabled: temporarily set `iam_database_authentication_enabled = false`, apply, wait a few minutes. **Observation:** the custom Guard rule turns **NON_COMPLIANT** (and in phase 07 the API cannot connect: `PAM authentication failed`). Revert.

## 🎤 Interview

1. How does an application on EKS connect to RDS without a password?
2. Multi-AZ vs read replica vs Aurora — when each?
3. Secrets Manager vs SSM Parameter Store?
4. How is RDS encrypted at rest and in transit?
