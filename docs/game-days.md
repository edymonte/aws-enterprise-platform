# Game days (phase 13, 5 h)

Receive each ticket without knowing the cause. Method: **Observation → Known facts → Hypothesis → Test → Evidence → Conclusion → Change (Git/Terraform) → Validation**. Write a 5-line post-mortem for each.

## GD-01 — "Customers see errors on the product page"
**Inject:** `chaos.errorRate: "0.3"` in prod (PR).
<details><summary>Resolution path</summary>AMP alert + Datadog monitor → recent Argo CD sync shows a values change → `git revert`. Prevention: CODEOWNERS on `gitops/envs/prod/`.</details>

## GD-02 — "Prod cannot reach the database, dev is fine"
**Inject:** delete the Pod Identity association for `portal-prod` in the console.
<details><summary>Resolution path</summary>`/readyz` 503 only in prod → logs show credential errors → `aws eks list-pod-identity-associations` → re-apply 40-eks. Argo CD cannot fix AWS-side drift.</details>

## GD-03 — "The site is down after a network change"
**Inject:** remove the CloudFront prefix-list rule from `sg-alb-mfs-portal-lab`.
<details><summary>Resolution path</summary>CloudFront returns 504; ALB healthy from your IP (operator rule) → SG inbound rules → prefix list missing → `apply 40-eks` restores it. Discuss drift detection (scheduled plan, Config rule on SG changes).</details>

## GD-04 — "Deploy succeeded but nothing changed"
**Inject:** set an image tag that does not exist in ECR (`v9.9.9`) in dev.
<details><summary>Resolution path</summary>`ImagePullBackOff` (`not found`), rolling update keeps old pods serving. Revert. Prevention: the pipeline only writes tags it pushed; ECR immutability prevents overwriting good tags.</details>

## GD-05 — "Pipeline can't deploy anymore"
**Inject:** change the deploy role trust subject to `environment:production` (Terraform), run the workflow.
<details><summary>Resolution path</summary>`Not authorized to perform sts:AssumeRoleWithWebIdentity` → it is the **trust policy** (authN), not the permissions policy (authZ). Compare token subject with the trust condition.</details>

## GD-06 — "Security team: a bucket became public"
**Inject:** enable the DR lab exception and leave it on.
<details><summary>Resolution path</summary>Config `s3-bucket-public-read-prohibited` NON_COMPLIANT, Security Hub finding. Close it (`allow_public_s3_website=false`), and add the auto-remediation challenge from phase 04.</details>

## GD-07 — "Primary site down — are we failing over?"
**Inject:** DR lab on + `chaos.errorRate: "1"` in prod.
<details><summary>Resolution path</summary>Route 53 health check unhealthy → `portal-dr` answers with the S3 website in sa-east-1. Measure the real failover time (interval × threshold + TTL). Discuss RTO/RPO and CloudFront origin groups as faster HTTP failover.</details>

## GD-08 — "Spot interruption" (optional)
**Inject:** `apply 40-eks -Var 'node_capacity_type=SPOT'`, then terminate one node instance in EC2.
<details><summary>Resolution path</summary>Managed node group replaces it; PDB keeps 1 API pod; HPA/topology spread keep serving. Discuss Spot for stateless workloads, capacity rebalancing, and Karpenter.</details>
