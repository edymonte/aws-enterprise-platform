# Review brief — AWS Enterprise Platform lab

> **For the reviewer (human or LLM):** this document is self-contained. It describes a hands-on lab that has been **written and statically validated but not yet deployed**. It is the AWS "twin" of an Azure lab with the same scenario. Please review it critically: correctness, security, cost, feasibility on a new AWS account, value for **AWS SAA-C03** study, and value for a multi-cloud DevOps interview. Specific questions are in section 11.

---

## 1. Context and goals

| Item | Detail |
|---|---|
| Learner | DevOps engineer focused on Azure (Azure DevOps, GitHub Actions GH-200, Terraform, Datadog/Dynatrace), also studying for **AWS SAA-C03**, targeting international roles. |
| Goal | Build the same production-shaped platform as the Azure lab on AWS, mostly with **Terraform**, and be able to explain Azure ↔ AWS differences in English. |
| Format | Guided lab: 15 phases, ≈ 58 h; each phase tagged with SAA-C03 domains (D1 secure, D2 resilient, D3 high-performing, D4 cost). Each phase: Goal → Concepts → Steps → Checkpoint → "Break it" → Interview questions → Challenge (from phase 04). |
| Scenario | Fictional **Monteiro Financial Services** — Customer Portal (Node.js API + static web). |
| Constraints | New personal AWS account (Free/Paid plan credits), region **us-east-1** (+ **sa-east-1** for DR), domain `edymonte.com.br` whose subdomain **`aws.edymonte.com.br`** is delegated to Route 53 from the parent zone (Azure DNS or Registro.br), Windows + PowerShell 7, human access via IAM Identity Center (no IAM user keys). |
| Status | Code complete. `terraform validate` passes on all 9 layers with Terraform 1.12.2 and 1.15.7; Helm chart lints; API unit tests pass. **Nothing applied to AWS yet.** |

## 2. Business requirements → platform answer

| # | Requirement | Implementation |
|---|---|---|
| 1 | Custom domain, HTTPS, web protection | Route 53 + ACM (us-east-1) + CloudFront + AWS WAF |
| 2 | Nothing public, no app passwords | Isolated DB subnets, RDS PostgreSQL with **IAM DB auth**, Secrets Manager, **EKS Pod Identity** |
| 3 | No manual deployments | GitOps with Argo CD; CI only pushes images and opens PRs |
| 4 | Auditable compliance | AWS Config (managed + **custom Guard** rule), GuardDuty (EKS audit + runtime), Security Hub (FSBP), Access Analyzer, account-level S3 public access block, EBS default encryption, IAM permissions boundary |
| 5 | Detect problems early | Amazon Managed Prometheus (**managed, agentless collector**), Grafana in cluster (SigV4), CloudWatch Container Insights, Datadog APM, SLO alerts → Alertmanager → SNS |
| 6 | Tested contingency | Route 53 **failover** routing with health check → static maintenance site in another region |
| 7 | Two CI/CD tools | GitHub Actions and Azure DevOps (AWS Toolkit), both via **OIDC → AssumeRoleWithWebIdentity** |

## 3. Architecture

```
Internet → Route 53 (aws.edymonte.com.br, alias A) → CloudFront (ACM cert, AWS WAF; CachingDisabled + AllViewer origin policy)
        → internet-facing ALB created by the AWS Load Balancer Controller (IngressGroup: one ALB for dev+prod,
          deterministic name alb-mfs-portal-lab), SG allows :80 only from managed prefix list
          com.amazonaws.global.cloudfront.origin-facing (+ operator IP)
        → target-type ip → pods in EKS (VPC 10.70.0.0/16, 2 AZs, private /20 subnets, VPC CNI with network policy)
        → RDS PostgreSQL in isolated database subnets (SG: 5432 from private subnet CIDRs), IAM auth token per connection
        → Secrets Manager secret mounted by Secrets Store CSI + AWS provider (Pod Identity)
Observability: pod annotations → AMP managed collector (ENIs in private subnets, EKS access entry + RBAC) → AMP
               → rule groups → Alertmanager → SNS (e-mail); Grafana (Argo CD) queries AMP via Pod Identity;
               CloudWatch Container Insights add-on; Datadog Operator/Agent + dd-trace
Delivery: GitHub Actions / Azure DevOps → test, build, Trivy, push to ECR (immutable tags) → PR bumping tag → Argo CD
```

## 4. Terraform design

- Layered root modules, one state object per layer in one S3 bucket; **S3 native locking (`use_lockfile = true`) — no DynamoDB**. `terraform_remote_state` between layers.
- Partial backend `backend "s3" {}` completed at `init` (bucket, region, encrypt, use_lockfile, key per layer).
- Providers/modules: `hashicorp/aws ~> 6.0`, `terraform-aws-modules/vpc/aws ~> 6.7`, `terraform-aws-modules/eks/aws ~> 21.0`, `DataDog/datadog ~> 4.0`, Terraform `>= 1.12.2, < 2.0.0`.
- `default_tags` in every provider (Owner, Environment, CostCenter, Layer, Project, ManagedBy).
- Stable `name_suffix` from `00-bootstrap` keeps names identical across the daily destroy/recreate cycle.
- Lifecycle script `scripts/awp.ps1` prints every Terraform command; before destroying `40-eks` it deletes Argo CD Applications and all Ingresses and waits for the ALB to disappear (otherwise orphaned ALB/ENIs block VPC deletion).

### Layers and what each one creates

| Layer | Resources |
|---|---|
| `00-bootstrap` (local state) | S3 state bucket (ownership controls, public access block, versioning, SSE-S3, lifecycle expiring noncurrent versions after 30 days, bucket policy denying non-TLS), Route 53 hosted zone `aws.edymonte.com.br`, AWS Budget (50/80% actual, 100% forecast), `random_string` suffix |
| `05-identity` | IAM OIDC provider for GitHub (`sts.amazonaws.com` audience); roles `mfs-github-plan` (trust `repo:<repo>:pull_request`, ReadOnlyAccess) and `mfs-github-deploy` (trust `repo:<repo>:environment:lab`, AdministratorAccess) — both with a **permissions boundary** denying IAM user/access-key/login-profile creation, Organizations/account/billing actions and boundary tampering; state bucket policy (List/Get/Put/Delete incl. `.tflock`); optional Azure DevOps OIDC provider (`vstoken.dev.azure.com/<org-id>`, audience `api://AzureADTokenExchange`, subject `sc://org/project/connection`) + role |
| `10-network` | VPC module: 2 AZs, private /20 ×2, public /24 ×2, database /24 ×2 with dedicated route table (no internet), single NAT gateway (toggle), ELB subnet tags, VPC flow logs to CloudWatch (7 days); S3 gateway endpoint; optional interface endpoints (ecr.api, ecr.dkr, sts, logs, secretsmanager); SNS alerts topic + e-mail subscription + topic policy for aps/cloudwatch/budgets |
| `20-governance` | Account S3 public access block (exception toggle for DR lab), EBS encryption by default, IAM Access Analyzer; Config: S3 delivery bucket + policy, service-linked role, recorder limited to SG/VPC/S3/RDS/EKS/IAM Role (`INCLUSION_BY_RESOURCE_TYPES`), delivery channel, status; managed rules (S3 public read, RDS public access, RDS encrypted, EKS endpoint no public access, VPC flow logs, restricted SSH, required tags); **custom Guard rule** "RDS must have IAM auth"; GuardDuty detector + features EKS_AUDIT_LOGS and RUNTIME_MONITORING (EKS add-on management); Security Hub + AWS FSBP standard |
| `30-data` | RDS PostgreSQL 16 db.t4g.micro (gp3 20 GB encrypted, `manage_master_user_password`, IAM auth, private, single-AZ, 1-day backups, no deletion protection), SG, Secrets Manager secrets for the banner and the Datadog API key (no values) |
| `40-eks` | EKS module v21: Kubernetes 1.33, public endpoint allow-listed to operator IP + private endpoint, `authentication_mode = "API"`, creator admin, control-plane logs audit/authenticator, add-ons vpc-cni (`enableNetworkPolicy`), eks-pod-identity-agent, coredns, kube-proxy; managed node group AL2023 t3.medium 1–3 (desired 2, ON_DEMAND/SPOT toggle); `amazon-cloudwatch-observability` add-on with Pod Identity; ECR repos (IMMUTABLE, scan on push, lifecycle keep 15); Pod Identity roles + associations for the API (`rds-db:connect` on `dbuser:<resource-id>/portal_api` + GetSecretValue on one secret; namespaces portal-dev/prod), AWS Load Balancer Controller (official IAM policy v3.6.0 file), CloudWatch agent; ALB security group with CloudFront prefix list |
| `50-edge` | Two providers (us-east-1, sa-east-1). Looks up ALB by name (`data "aws_lb"`). ACM cert (portal, portal-dev, optional portal-dr) + Route 53 validation records + validation; WAFv2 web ACL (CLOUDFRONT): AWSManagedRulesCommonRuleSet, KnownBadInputs, SQLi (override count/none by `waf_mode`), rate-based rule; CloudFront distribution (aliases, ALB origin http-only, custom header `X-Origin-Verify`, managed cache/origin-request policies, TLSv1.2_2021, PriceClass_100); alias A records. **DR lab (optional):** S3 website bucket named `portal-dr.aws.edymonte.com.br` in sa-east-1 (public read — requires the governance exception, flagged by Config), maintenance page object, Route 53 HTTPS health check on `portal…/api/products`, failover PRIMARY (CloudFront) / SECONDARY (S3 website) records |
| `60-observability` | AMP workspace; `aws_prometheus_scraper` (EKS source: cluster ARN, private subnets, cluster SG; scrape config: annotated pods, kube-state-metrics, cAdvisor via API proxy); EKS access entry for the scraper role (user `aps-collector-user`); rule group namespace (error ratio, p95, restarts); Alertmanager definition → SNS (SigV4); Grafana Pod Identity role (AmazonPrometheusQueryAccess) |
| `70-datadog` | Same as Azure lab: monitors (APM error rate, p95, restarts), SLO, dashboard via `templatefile()` |

## 5. Application and GitOps

- **API**: Node.js 24/Express, RED metrics, chaos switches, `pg` + `@aws-sdk/rds-signer` (token as password function, TLS with RDS CA bundle downloaded into the image), Secrets Manager banner via CSI file; optional dd-trace.
- **Helm chart**: ServiceAccount (no annotations — Pod Identity), Deployments with `prometheus.io/*` annotations, Services (ALB health-check annotation), Ingress (`alb` class; scheme internet-facing; target-type ip; `group.name`; `load-balancer-name`; `security-groups` + `manage-backend-security-group-rules`), SecretProviderClass (`provider: aws`, `usePodIdentity: "true"`), HPA, PDB, NetworkPolicy (ipBlock VPC CIDR + datadog/kube-system namespaces).
- **Argo CD** (Helm, once) + app-of-apps: AWS Load Balancer Controller chart 3.6.0, Secrets Store CSI driver 1.6.1, ASCP 3.1.4, kube-state-metrics 8.6.0, Grafana 10.5.15 (multi-source: chart + values from repo; dashboard JSON pulled from GitHub raw), RBAC for the AMP collector, portal-dev, portal-prod; Datadog Operator/Agent as an opt-in add-on.
- **Scripts**: render GitOps values from Terraform outputs; build/push images to ECR (Docker); create the DB user `portal_api` (`GRANT rds_iam`) by running `psql` in a temporary pod inside the VPC with the master password from Secrets Manager passed through a temporary K8s Secret; Datadog secret from Secrets Manager.

## 6. CI/CD

| Pipeline | GitHub Actions | Azure DevOps |
|---|---|---|
| Quality | fmt/validate × 9 layers, npm test, helm lint, Trivy config, secret grep | — |
| Infra | PR: plan matrix with **plan role** (read-only), `-lock=false`, PR comment; manual: plan/apply/destroy with **deploy role**, environment `lab` approval | AWS Toolkit `AWSShellScript@1` with an **OIDC-enabled AWS service connection** (role from 05-identity); Validate → Plan → Apply (deployment job, environment approval) |
| App | test → build → Trivy (fail CRITICAL) → push ECR (`amazon-ecr-login`) → PR bump dev; promotion PR | same; GitOps PR via PAT from variable group |

## 7. Lab plan (≈ 58 h)

00 prerequisites (Identity Center SSO, quotas) 2h · 01 bootstrap + subdomain delegation 2h · 02 OIDC roles + boundary (challenge: close the CreateRole escalation path) 3h · 03 VPC, NAT SPOF, endpoints 4h · 04 Config/GuardDuty/Security Hub (challenge: auto-remediation) 4h · 05 RDS IAM auth 4h · 06 EKS + Pod Identity 6h · 07 GitOps, ALB, first delivery 6h · 08 GitHub Actions 3h · 09 Azure DevOps → AWS 4h · 10 CloudFront/WAF/Route 53 failover (challenge: verify origin header at ALB) 5h · 11 AMP/Grafana/Logs Insights 4h · 12 Datadog 4h · 13 8 game days 5h · 14 portfolio 2h.

Extras: `docs/AZURE-AWS-MAPPING.md` (side-by-side of both labs), 6 ADRs, interview pack with ~30 AWS Q&A tagged by SAA-C03 domain.

## 8. Cost model (estimates, unverified)

Hourly while up: EKS control plane (~$0.10/h), 2 × t3.medium (~$0.08/h), NAT gateway (~$0.045/h + data), ALB (~$0.023/h + LCU); RDS db.t4g.micro free-tier eligible; WAF web ACL + rules prorated; AMP per sample + collector hour; GuardDuty/Security Hub on 30-day trials. Estimated $2–5 per 8-hour day. Daily `down` keeps only the state bucket, hosted zone, budget and IAM.

## 9. Known trade-offs (ADRs)

1. S3 native locking instead of DynamoDB (requires TF ≥ 1.10).
2. Pod Identity over IRSA.
3. Community modules for VPC/EKS only.
4. Two AZs, single NAT gateway.
5. Public ALB origin locked by prefix list (+ header challenge) instead of CloudFront VPC origins; DR via public S3 website with a temporary account-level exception.
6. RDS PostgreSQL (IAM auth) instead of SQL Server (no IAM auth on RDS SQL Server).
7. Pipeline deploy role = AdministratorAccess ∩ boundary — known escalation path via CreateRole without boundary (left as challenge).
8. EKS public endpoint (allow-listed) → Config rule `eks-endpoint-no-public-access` is NON_COMPLIANT by design.
9. Single AWS account (management account of an org created by Identity Center) — SCPs discussed but not applied (they do not affect the management account).

## 10. Unverified assumptions / risks I am least sure about

1. **EKS module v21 inputs** (validated syntactically): `addons` with `before_compute`, `enabled_log_types`, `endpoint_public_access_cidrs`, node group defaults (IMDS hop limit 2 so the LB Controller can discover region/VPC without explicit values).
2. **AMP managed collector** scrape config: is `authorization.credentials_file` / `tls_config.ca_file` supported for the cAdvisor job? Is the cluster security group the right `security_group_ids`? Does the collector need extra SG rules to reach pods/API server?
3. **Config custom policy** Guard syntax and the field name `configuration.iAMDatabaseAuthenticationEnabled`.
4. **Config service-linked role** creation in a fresh account and recreation during the daily cycle.
5. **GuardDuty feature** `RUNTIME_MONITORING` with `EKS_ADDON_MANAGEMENT` — correct names for provider v6?
6. **CloudFront → ALB** with the AllViewer policy forwarding Host; ALB listener rules by host; IngressGroup with both namespaces sharing `load-balancer-name`.
7. **Prefix list** in SG ingress (≈55 rules) plus LB Controller-managed backend rules — any quota conflicts?
8. **Route 53 failover** with alias to an S3 website endpoint in sa-east-1 (`aws_s3_bucket.hosted_zone_id` + `website_domain`) and primary alias to CloudFront with a health check.
9. **Azure DevOps OIDC to AWS** via the AWS Toolkit: issuer URL format, audience `api://AzureADTokenExchange`, subject `sc://org/project/name` — current behaviour of the extension.
10. **ASCP with Pod Identity** (`usePodIdentity: "true"`) and chart 3.x values (`secrets-store-csi-driver.install: false`).
11. **Grafana** SigV4 with Pod Identity credentials (Grafana's AWS SDK support for the container credentials endpoint).
12. **Free plan accounts**: are EKS, CloudFront, WAF, GuardDuty, Security Hub and AMP available without upgrading to the Paid plan?
13. **DB user script**: `kubectl run --overrides` with `envFrom` secret and `psql` connection string with `sslmode=require`.

## 11. Questions for the reviewer

1. **Security**: flaws in IAM trust policies, the boundary, Pod Identity scopes, network exposure, secrets handling?
2. **Apply-time failures**: which resources/arguments are likely to fail despite `terraform validate` (focus on section 10)?
3. **Cost**: realistic? What would you change for a learner paying out of pocket?
4. **SAA-C03 value**: which exam topics are well covered, and which important ones are missing (e.g. Auto Scaling groups, Aurora, DynamoDB, SQS/SNS/EventBridge decoupling, Lambda, S3 storage classes, Direct Connect, Organizations/Control Tower)?
5. **Multi-cloud interview value**: does the Azure ↔ AWS comparison hold up? Any inaccurate equivalences?
6. **Design improvements** you would prioritize (top 5), keeping the 80/20 focus.
7. Overall rating (1–10) for technical correctness, security, learning value, SAA-C03 relevance, interview relevance — one sentence each.
