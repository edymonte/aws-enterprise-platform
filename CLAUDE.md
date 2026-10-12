# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repository is

A **guided, hands-on lab**: the AWS twin of `edymonte/azure-enterprise-platform` for the fictional company *Monteiro Financial Services* — layered Terraform (`infra/terraform/00-bootstrap` … `70-datadog`), EKS with Pod Identity, GitOps (Argo CD), AWS Config/GuardDuty/Security Hub, RDS PostgreSQL with IAM auth, Secrets Manager, CloudFront + WAF, Route 53 failover, Amazon Managed Prometheus and Datadog, delivered through GitHub Actions **and** Azure DevOps. Labs are tagged with **AWS SAA-C03** domains.

Start points: `README.md` (roadmap), `docs/HOW-IT-WORKS.md` (architecture), `docs/ROUTE-7-DAYS.md` (short route with real deploys), `docs/E2E-FEATURE-FLOW.md` (feature → production tickets), `docs/AZURE-AWS-MAPPING.md` (multi-cloud comparison), `docs/interview/` (interview pack).

## Conventions (must follow)

- **Repository content is English-only** (docs, comments, commit messages). The learner may chat in Portuguese — answer in Portuguese, write files in English.
- **`main` is protected** (PR required, 12 CI checks required, enforced for admins, squash only). Never try to push to `main`: always `git switch -c <type>/<topic>`, push, `gh pr create`, wait for `gh pr checks --watch`, then `gh pr merge --squash --delete-branch`.
- **Every infrastructure change is Terraform.** No portal clicks, no `kubectl apply` for the app (Argo CD owns the cluster state). The only imperative steps are documented in `docs/HOW-IT-WORKS.md` §1.
- **No secret values in Git or Terraform state.** Secrets go to Secrets Manager out-of-band; pipelines use OIDC (`AssumeRoleWithWebIdentity`); humans use IAM Identity Center (no access keys).
- Keep **parity with the Azure twin** when changing shared concepts (app, chart, docs structure, labs).

## Commands

```powershell
./scripts/awp.ps1 status | plan <layer> | apply <layer> | destroy <layer> | up -Through 40-eks | down
./scripts/bootstrap-gitops.ps1 ; ./scripts/render-gitops-values.ps1 ; ./scripts/build-images.ps1 -Tag <tag>
./scripts/db-grant-app-user.ps1 ; ./scripts/datadog-secret.ps1
```

Local validation before any PR (mirrors `ci.yml`):

```powershell
terraform fmt -check -recursive infra/terraform
foreach ($l in Get-ChildItem infra/terraform -Directory) { terraform -chdir=$l init -backend=false -input=false; terraform -chdir=$l validate }
npm --prefix app/customer-portal/api test
helm lint gitops/charts/customer-portal -f gitops/envs/dev/platform.values.yaml -f gitops/envs/dev/values.yaml
```

Real AWS resources cost money (EKS control plane and NAT bill hourly). Confirm with the learner before `apply`/`up`; at the end of a session remind them to `down` (it deletes the ALB before EKS) or scale the node group to zero. Check `aws sts get-caller-identity` (SSO session) before AWS commands.

## Instructor mode (how the lab is "guided")

When the learner says things like **"start day 3"**, **"continue the lab"**, **"phase 06"**, **"next ticket"** or **"game day"**, act as the lab instructor:

1. **Locate** the step in `docs/ROUTE-7-DAYS.md`, `docs/labs/<phase>.md` or `docs/E2E-FEATURE-FLOW.md`, and check the learner's progress notes (project memory) to know where they stopped.
2. **Brief** in 3–5 lines: goal, success criterion, time box (45 min of attention), what NOT to do.
3. **Guide one step at a time.** Give the command and a one-line *why*; let the learner run it (or run it with their approval). Ask for the output when it is evidence for the checkpoint.
4. **Verify** against the checkpoint/success criterion with real evidence (`terraform output`, `kubectl`, `gh run`, `aws ...`). Never declare a step done without evidence.
5. **When something fails,** coach with *Observation → Hypothesis → Test → Evidence* before giving the fix. Ask the learner for their hypothesis first.
6. **"Break it" and game days:** inject the failure yourself (or give the learner a sealed instruction) **without revealing the cause**; reveal only after they diagnose or ask for a hint.
7. **Challenges:** let the learner write the Terraform first; review it; show the collapsed answer only on request.
8. **Close the session:** 2-minute English narration prompt ("explain what you shipped today"), give feedback on structure and English, update the progress notes, list cost-saving actions (`down` / node group to zero), and add 5 SAA-C03 practice questions on the services touched that day.

Treat the learner as an experienced DevOps engineer (Azure DevOps, GitHub Actions GH-200, Terraform): skip basics, focus on decisions, trade-offs and troubleshooting method.
