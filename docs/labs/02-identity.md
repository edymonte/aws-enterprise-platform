# Phase 02 — Identity: OIDC roles and a permissions boundary (3 h)

📘 **SAA-C03:** D1 (IAM roles, federation, least privilege, permissions boundaries)

## 🎯 Goal

Let GitHub Actions (and later Azure DevOps) change AWS with **temporary credentials only**, and limit what even an admin-like pipeline role can do.

## 🧠 Concepts

```text
GitHub job ── OIDC token (sub = repo:edymonte/aws-enterprise-platform:environment:lab)
          └─► STS AssumeRoleWithWebIdentity ── trust policy checks aud + sub ──► 1-hour credentials
```

| Role | Who can assume | Permissions | Used for |
|---|---|---|---|
| `mfs-github-plan` | any PR (`:pull_request`) | `ReadOnlyAccess` + state bucket | `terraform plan` on PRs |
| `mfs-github-deploy` | only jobs in environment `lab` | `AdministratorAccess` **∩ boundary** | apply / image push |
| `mfs-azure-devops-deploy` | one ADO service connection | same as deploy | phase 09 |

**Permissions boundary** = the maximum a role can ever do, whatever policies are attached. Effective permissions = identity policies **∩** boundary (**∩** SCPs, if in an Organization).

## 🛠️ Steps

1. Read `05-identity/main.tf`: the trust policies are generated with `for_each` over a map `{plan = [...subjects], deploy = [...]}`.
2. `./scripts/awp.ps1 apply 05-identity`
3. Configure GitHub:

```powershell
$id = terraform -chdir=infra/terraform/05-identity output -json | ConvertFrom-Json
$bs = terraform -chdir=infra/terraform/00-bootstrap output -json | ConvertFrom-Json
$repo = 'edymonte/aws-enterprise-platform'
gh variable set AWS_PLAN_ROLE_ARN   -R $repo -b $id.github_plan_role_arn.value
gh variable set AWS_DEPLOY_ROLE_ARN -R $repo -b $id.github_deploy_role_arn.value
gh variable set AWS_REGION          -R $repo -b us-east-1
gh variable set TF_STATE_BUCKET     -R $repo -b $bs.state_bucket.value
gh variable set NAME_SUFFIX         -R $repo -b $bs.name_suffix.value
gh variable set ALERT_EMAIL         -R $repo -b '<your-email>'
gh variable set OPERATOR_IP_RANGES  -R $repo -b '["<your-ip>/32"]'
gh api -X PUT "repos/$repo/environments/lab" -f "reviewers[][type]=User" -F "reviewers[][id]=$(gh api user --jq .id)"
```

## ✅ Checkpoint

- [ ] `aws iam get-role --role-name mfs-github-deploy --query Role.PermissionsBoundary` shows the boundary.
- [ ] *IAM → Identity providers* lists `token.actions.githubusercontent.com`.

## 💥 Break it — escalation path

The deploy role can create **new roles without a boundary** and attach `AdministratorAccess` to them — then the boundary is bypassed. Use the IAM policy simulator (*IAM → Policy simulator*) on `mfs-github-deploy` for `iam:CreateUser` (denied) and `iam:CreateRole` (allowed). **This is the known gap.** → Challenge.

## 🏋️ Challenge — close the escalation path

Make the boundary require that any role the pipeline creates **also** carries the boundary.

<details><summary>Answer</summary>

Add to the boundary document:

```hcl
statement {
  sid       = "RequireBoundaryOnNewRoles"
  effect    = "Deny"
  actions   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
  resources = ["*"]
  condition {
    test     = "StringNotEquals"
    variable = "iam:PermissionsBoundary"
    values   = [aws_iam_policy.boundary.arn]   # careful: self-reference → use the ARN string
  }
}
```

Then every role created by Terraform (EKS module, Pod Identity roles) must set `permissions_boundary` (the EKS module exposes `iam_role_permissions_boundary`). This is exactly the trade-off platform teams negotiate: stronger guardrail, more plumbing in every module.

</details>

## 🎤 Interview

1. Walk me through GitHub OIDC to AWS. What exactly does the trust policy check?
2. Identity policy vs resource policy vs permissions boundary vs SCP — how are they evaluated?
3. Why separate plan and deploy roles?
4. How can a role with a boundary still escalate privileges, and how do you stop it?
