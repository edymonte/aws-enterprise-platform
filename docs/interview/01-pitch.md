# The pitch

## 30 seconds

> "I built the same enterprise reference platform on Azure and on AWS, fully in Terraform with one state per layer. On AWS it's EKS with Pod Identity, the application reaches RDS PostgreSQL with IAM authentication — so no database password — and traffic only enters through CloudFront and AWS WAF; the ALB's security group allows just the CloudFront prefix list. Pipelines in GitHub Actions and Azure DevOps assume IAM roles through OIDC, deployments are GitOps with Argo CD, and governance is AWS Config with a custom Guard rule, plus GuardDuty and Security Hub."

## 2 minutes — walk through the architecture

1. **Context** — "Same requirements as the Azure version: custom domain with WAF, nothing public, no manual deploys, auditable compliance, two CI tools."
2. **Entry** — "Route 53 hosted zone for a delegated subdomain, ACM certificate in us-east-1, CloudFront with managed caching disabled and the AllViewer origin policy so the Host header reaches the ALB. AWS WAF with the common, known-bad-inputs and SQLi rule groups plus a rate rule — first in count mode, then block."
3. **Compute and identity** — "EKS with access entries instead of aws-auth, managed node group across two AZs, VPC CNI with network policies. Pod Identity associations map each namespace's service account to an IAM role; the API role can only `rds-db:connect` as one database user and read one secret."
4. **Network** — "VPC with public, private and isolated database subnets in two AZs; a single NAT gateway as a documented lab trade-off; a free S3 gateway endpoint so ECR layers don't go through NAT."
5. **Delivery** — "CI builds, scans with Trivy, pushes to ECR with immutable tags, and opens a PR on the GitOps folder; Argo CD syncs. Promotion is a PR; rollback is a revert."
6. **Governance & ops** — "AWS Config managed rules plus a Guard rule requiring IAM auth on RDS, account-level S3 public access block, EBS encryption by default, GuardDuty with EKS runtime monitoring, Security Hub FSBP. Metrics via the Amazon Managed Prometheus agentless collector, alerts through Alertmanager to SNS, Grafana in the cluster with SigV4, and Datadog APM."
7. **Trade-off** — "For production I'd use CloudFront VPC origins with an internal ALB, a NAT per AZ, a private EKS endpoint with self-hosted runners, and SCPs from an Organization."

## Likely follow-ups

| Question | One-liner |
|---|---|
| "IRSA or Pod Identity?" | "Pod Identity now: no OIDC provider in every trust policy, no SA annotations, roles reusable across clusters; IRSA still for Fargate or older tooling." |
| "How did you lock state?" | "S3 native lock files with `use_lockfile` — no DynamoDB table since Terraform 1.10." |
| "Biggest difference vs Azure?" | "AZ-scoped subnets and pods consuming VPC IPs; preventive org-wide guardrails need SCPs, whereas Azure Policy can deny at any scope." |
| "Something that bit you?" | "The ALB is created by a controller, not Terraform — destroying the cluster first orphans it and blocks VPC deletion. I added a pre-destroy step." |
