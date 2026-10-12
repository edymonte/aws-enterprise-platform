# Phase 09 — CI/CD with Azure DevOps → AWS (4 h)

📘 **SAA-C03:** D1 (federation)

## 🎯 Goal

Run the same Terraform and image pipelines from Azure DevOps against AWS using **OIDC** — no access keys in a service connection.

## 🧠 Concepts

The **AWS Toolkit for Azure DevOps** extension provides an *AWS* service connection type and tasks (`AWSShellScript@1`, `ECRPushImage@1`, …). With **Use OIDC** enabled, the task gets an Azure DevOps OIDC token (issuer `https://vstoken.dev.azure.com/<organization-id>`, subject `sc://<org>/<project>/<service-connection>`) and calls `AssumeRoleWithWebIdentity` on the role you configure.

> Verify the current OIDC options of the AWS Toolkit before you start — the feature set of marketplace extensions evolves. The fallback (documented in the Azure twin's refresher) is a self-hosted agent on EC2 with an instance profile.

## 🛠️ Steps

1. Install **AWS Toolkit for Azure DevOps** from the Marketplace in your organization.
2. Find your **organization ID** (GUID): *Organization settings → Microsoft Entra* or the `_apis/connectionData` API.
3. Create `infra/terraform/05-identity/terraform.tfvars` (git-ignored):

   ```hcl
   ado_organization_id            = "<org-guid>"
   ado_service_connection_subject = "sc://edymonte-lab/mfs-platform/aws-mfs-lab-oidc"
   ```

4. `./scripts/awp.ps1 apply 05-identity` → note `ado_role_arn`.
5. *Project settings → Service connections → New → AWS* → name `aws-mfs-lab-oidc`, **Use OIDC** ✓, **Role to assume** = `ado_role_arn`.
6. Variable groups: `mfs-aws-common` (`TF_STATE_BUCKET`, `AWS_REGION`, `ALERT_EMAIL`, `OPERATOR_IP_RANGES`, `NAME_SUFFIX`) and `mfs-aws-app` (`ECR_REGISTRY`, secret `GITOPS_GITHUB_TOKEN`).
7. Environment `mfs-aws-lab` with an approval check.
8. New pipelines from `pipelines/azure-devops/infra.yml` and `app.yml`.

## ✅ Checkpoint

- [ ] `infra` Plan stage succeeds; Apply waits for approval.
- [ ] CloudTrail shows `AssumeRoleWithWebIdentity` with issuer `vstoken.dev.azure.com`.

## 💥 Break it

Rename the service connection in Azure DevOps. **Observation:** STS denies the call — the subject `sc://org/project/<name>` changed. **Lesson:** the service connection *name* is part of the identity; renames are security-relevant changes.

## 🎤 Interview

1. How do you let Azure DevOps deploy to AWS without storing access keys?
2. What is in the ADO OIDC subject, and what does that imply for renames?
3. Compare: GitHub OIDC → AWS vs ADO OIDC → AWS vs ADO WIF → Azure.
