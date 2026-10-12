# Phase 00 — Prerequisites (2 h)

## 🎯 Goal

Account, tools, human access without long-lived keys, and the repository — ready for `./scripts/awp.ps1 bootstrap`.

## 🛠️ Steps

### 1. Tools (Windows, PowerShell 7)

```powershell
winget install --id Hashicorp.Terraform        # >= 1.12.2
winget install --id Amazon.AWSCLI
winget install --id Kubernetes.kubectl
winget install --id Helm.Helm
winget install --id Git.Git
winget install --id GitHub.cli
winget install --id OpenJS.NodeJS.LTS
winget install --id Docker.DockerDesktop        # image builds (phase 07)
```

### 2. AWS account and human access (no IAM user keys)

1. Create a new AWS account with a personal e-mail. Enable **MFA on the root user** and stop using root.
2. Enable **IAM Identity Center** (it creates an AWS Organization with this account as management account). Create a user for yourself, a permission set `AdministratorAccess`, and assign it to the account.
3. Configure the CLI with SSO:

```powershell
aws configure sso          # profile name: mfs-lab, region: us-east-1
$env:AWS_PROFILE = 'mfs-lab'
aws sso login
aws sts get-caller-identity
```

> 📘 SAA-C03 D1: root user protection, MFA, federated access with temporary credentials, why IAM users with access keys are the last resort.

### 3. Your public IP

```powershell
"$(Invoke-RestMethod https://api.ipify.org)/32"
```

Used by the EKS public endpoint allow-list and the ALB security group (testing before CloudFront exists).

### 4. GitHub repository

```powershell
cd C:\Projects\aws-enterprise-platform
gh repo create edymonte/aws-enterprise-platform --public --source . --remote origin
git add -A; git commit -m "chore: initial platform scaffold"; git push -u origin main
```

### 5. Lab settings

```powershell
Copy-Item config/lab.settings.example.json config/lab.settings.json
code config/lab.settings.json      # region, alertEmail, operatorIpRanges, publicZoneName, monthlyBudgetUsd
```

### 6. Check service quotas

```powershell
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A `
  --query "Quota.Value"   # Running On-Demand Standard instances (vCPUs) — need >= 4
```

## ✅ Checkpoint

- [ ] `aws sts get-caller-identity` shows an `AWSReservedSSO_AdministratorAccess_...` role — not root, not an IAM user.
- [ ] Repository pushed; `config/lab.settings.json` filled (git-ignored).

## 🎤 Interview

1. Why is IAM Identity Center preferred over IAM users for humans?
2. What would you do in the first hour of a brand-new AWS account?
