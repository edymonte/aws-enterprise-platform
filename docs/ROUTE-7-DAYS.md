# 7-day personal route — real E2E delivery on AWS (multi-cloud + SAA-C03 edition)

Built with the **"personal route architect"** prompt:

> My goal is **to answer "what about AWS?" with real experience in a multi-cloud DevOps interview and progress on SAA-C03**: to **deploy the AWS twin platform, ship features from a feature branch to production on EKS through PRs, CI, GitOps and smoke tests, and explain the Azure ↔ AWS differences I hit** within **7 days** — not to learn AWS in general.
> I already master **Azure DevOps, GitHub Actions (GH-200), Terraform, Azure platform concepts, and SAA-C03 basics (EC2, IAM fundamentals)**.
> Build a 7-day route with one daily task of **at most 45 minutes of attention**, a success criterion, and what NOT to do. Redo it until it leads to the goal.

## Rules of the route

- **45 minutes of attention per day**; long applies (EKS ≈ 15 min, RDS ≈ 10 min) run **unattended**.
- **Every change is a commit** — flow in [E2E-FEATURE-FLOW.md](E2E-FEATURE-FLOW.md).
- **Keep the platform up from day 2 to day 6.** EKS cannot be "stopped" like AKS: the control plane (~US$0.10/h) and the NAT gateway (~US$0.045/h) bill continuously. At night, scale nodes to zero to save the biggest part:
  ```powershell
  aws eks update-nodegroup-config --cluster-name eks-mfs-portal-lab --nodegroup-name <name> --scaling-config minSize=0,maxSize=3,desiredSize=0   # evening
  aws eks update-nodegroup-config --cluster-name eks-mfs-portal-lab --nodegroup-name <name> --scaling-config minSize=1,maxSize=3,desiredSize=2   # morning
  ```
  Estimated week: **≈ US$20–30**. **No CloudFront/WAF** this week — PostSync smoke is the verification; `smoke.yml` skips.
- **SAA tie-in (10 min/day):** 5 practice questions on the service you touched that day; wrong answers go to your mistakes log.
- **Re-plan rule:** a failed criterion moves to the first slot of the next day.

## The route

| Day | Task (≤ 45 min attention) | Success criterion | SAA tie-in | Don't |
|---:|---|---|---|---|
| 1 | **Foundation.** IAM Identity Center + `aws sso login` → `awp.ps1 bootstrap` → NS delegation of `aws.edymonte.com.br` → `apply 05-identity` → GitHub variables + `lab` environment → public repo + branch protection. Start `up -Through 30-data` unattended. | State in S3 with `.tflock` behaviour seen; OIDC provider + plan/deploy roles with boundary; layers 05–30 applied. | IAM federation, permissions boundaries (D1) | Don't create IAM users with access keys. |
| 2 | **First deploy, part 1.** `apply 40-eks` (unattended) → `render-gitops-values.ps1` PR → `build-images.ps1 -Tag v1.0.0` (Docker) + tags PR. | ECR has both images (immutable tags); Pod Identity associations listed; values PR merged. | ECR, EKS, VPC CNI IP usage (D2/D3) | Don't apply 50/60 yet. |
| 3 | **First deploy, part 2 + FEAT-01.** `bootstrap-gitops.ps1` → `db-grant-app-user.ps1` → apps Healthy → FEAT-01 full loop dev → prod. | `SMOKE OK` in dev and prod for `<sha>`; ALB (one, IngressGroup) serving both hosts; evidence block filled. | ALB vs NLB, target-type ip (D3) | Don't push to `main`; don't build a separate prod image. |
| 4 | **FEAT-03 + FEAT-04 — quality gates.** Bug blocked in PR; bad SQL release passes unit tests, fails PostSync smoke in dev → revert. | Red → green PR; dev sync `Failed` then restored by revert; prod untouched. | RDS Multi-AZ vs read replica, IAM DB auth (D1/D2) | Don't `kubectl rollout undo`. |
| 5 | **FEAT-05 — infra change with approval.** `portal-qa` (Pod Identity association + GitOps app) via PR plan comment → merge → `infra` workflow apply with approval. | Plan `1 to add, 0 to destroy`; approval recorded; `portal-qa` Healthy and connecting to RDS. | Least privilege, plan vs deploy roles (D1) | Don't apply from the laptop this time. |
| 6 | **FEAT-07 rollback drill + Azure↔AWS write-up.** Inject latency via deploy PR → detect (AMP alert if 60 is up, else pod metrics/logs) → `git revert`. Then write 5 differences you actually hit vs the Azure lab. | Revert restores latency; 5 differences written with "why it matters". | Monitoring choices, CloudWatch vs AMP (D2) | Don't apply CloudFront for this. |
| 7 | **Mock + teardown.** Mock (30 min): "Have you worked with AWS?" → E2E story (FEAT-01 + FEAT-04) → 5 differences → 10 SAA questions. Then `awp.ps1 down` (removes the ALB first) — confirm no ALB/NAT left. | ≥ 7/10 SAA; multi-cloud answer ≤ 2 min; `aws elbv2 describe-load-balancers` and NAT list empty. | Mixed D1/D2 | Don't leave NAT or EKS running. |

## What this route skips (and when)

| Skipped | Lab phase | When |
|---|---|---|
| CloudFront + WAF + Route 53 failover, public smoke test | 10 | after, 1 day, then destroy |
| Config/GuardDuty/Security Hub hands-on | 04 | 1 hour later; read the lab now |
| AMP + Grafana dashboards | 11 | optional on day 6 if time |
| Datadog | 12 | after |
| Azure DevOps → AWS | 09 | after the Azure route's day 6 (same concepts) |

## Redo loop

Bring the gap list and SAA scores back: *"Redo the AWS route with these gaps and scores: …"* — repeat until the mock passes twice.

## Daily log

| Day | Criterion met? | Evidence (PR / run) | SAA score | What failed → redo |
|---:|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 7 | | | | |
