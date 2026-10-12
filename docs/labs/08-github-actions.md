# Phase 08 — CI/CD with GitHub Actions (3 h)

📘 **SAA-C03:** D1 (temporary credentials, least privilege)

## 🎯 Goal

Same three flows as the Azure twin — quality gate, infra plan/apply, app build → PR — with `aws-actions/configure-aws-credentials` and **two roles**.

| Workflow | Role assumed | OIDC subject |
|---|---|---|
| `infra.yml` on PR | `mfs-github-plan` (read-only) | `repo:...:pull_request` |
| `infra.yml` manual | `mfs-github-deploy` (bounded admin) | `repo:...:environment:lab` |
| `app.yml` | `mfs-github-deploy` | `repo:...:environment:lab` |

## 🛠️ Steps

1. Variables from phase 02 in place; environment `lab` has you as reviewer.
2. PR touching `infra/` → plans per layer posted as PR comments, using the **read-only** role.
3. *Run workflow* `infra` → approval → plan/apply with the deploy role.
4. Change `app/customer-portal/web/index.html`, merge → build, Trivy, push to ECR, automatic deploy PR.

## ✅ Checkpoint

- [ ] CloudTrail shows `AssumeRoleWithWebIdentity` events with the GitHub subject (*CloudTrail → Event history*).
- [ ] No access keys exist anywhere (`aws iam list-users` is empty except what you created on purpose).

## 💥 Break it

Run the manual `infra` workflow **without** the `environment: lab` line (edit it on a branch). **Observation:** `Not authorized to perform sts:AssumeRoleWithWebIdentity`. **Evidence:** the token's subject becomes `repo:...:ref:refs/heads/<branch>`, which the deploy role does not trust. Exactly the protection you want.

## 🎤 Interview

1. What does the `sub` claim look like for a PR, a branch and an environment?
2. Why give PR plans a read-only role? What can a malicious PR still do with it?
3. How would you restrict ECR push to the app pipeline only? *(separate role with an ECR-scoped policy instead of the deploy role)*
