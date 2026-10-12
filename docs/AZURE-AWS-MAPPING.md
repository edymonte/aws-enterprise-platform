# Azure ↔ AWS mapping (as built in these two labs)

Use this as a "Rosetta Stone" in multi-cloud interviews: same requirement, two implementations, and the differences that matter.

| Concern | Azure project | AWS project | Difference worth mentioning |
|---|---|---|---|
| Terraform state | Storage account blob, Entra ID auth, blob lease lock | S3 bucket, `use_lockfile` lock file | S3 native locking (TF ≥ 1.10) replaced the DynamoDB lock table |
| Hierarchy / guardrails | Subscription + Azure Policy | Account + Config / SCP (Organizations) | Azure Policy can **deny** at any scope; in AWS, preventive org-wide denies need SCPs |
| Detective compliance | Policy in Audit | AWS Config rules (managed + Guard custom) | Config records resource history (timeline) |
| Threat detection / posture | Defender for Cloud | GuardDuty + Security Hub (+ Inspector) | AWS splits it into several services |
| Pipeline identity | Entra app + federated credential | IAM OIDC provider + role trust policy | Same OIDC idea; AWS adds permissions boundaries |
| Network | VNet hub & spoke, peering | VPC across AZs (hub = Transit Gateway in multi-VPC) | AWS subnets are **AZ-scoped**; Azure subnets are regional |
| Outbound | Load Balancer SNAT / NAT Gateway | NAT Gateway (per AZ for HA) | NAT is a real cost driver on AWS |
| Private PaaS access | Private Endpoint + private DNS zone | Interface endpoint (PrivateLink) / gateway endpoint (S3, DynamoDB) | Gateway endpoints are free; RDS lives *in* your VPC anyway |
| Kubernetes | AKS | EKS | EKS control plane is billed hourly; AKS Free tier is not |
| Cluster access | Entra ID + Azure RBAC | EKS access entries (IAM) | Both replace legacy local accounts / `aws-auth` |
| Pod → cloud identity | Workload Identity (federated credential) | EKS Pod Identity (association) or IRSA | Pod Identity needs no per-cluster trust edits |
| Pod networking | CNI Overlay + Cilium | VPC CNI (pods get VPC IPs) + network policy agent | AWS pods consume subnet IPs → size subnets for pods |
| Ingress | App Routing (managed NGINX) | AWS Load Balancer Controller → ALB | ALB targets pod IPs directly (target-type ip) |
| Registry | ACR | ECR (immutable tags, scan on push) | |
| Database | Azure SQL, Entra-only auth | RDS PostgreSQL, IAM DB auth | IAM DB auth: MySQL/PostgreSQL only; tokens last 15 min |
| Secrets | Key Vault + CSI | Secrets Manager + CSI (ASCP) | RDS can manage its master password in Secrets Manager |
| Edge | Front Door + WAF policy | CloudFront + AWS WAF web ACL | CloudFront certs/WAF must be in **us-east-1** |
| Origin lock | NSG service tag `AzureFrontDoor.Backend` (+ X-Azure-FDID) | SG with CloudFront managed prefix list (+ custom header) | Prefix list weighs ~55 rules in an SG |
| DNS failover | Traffic Manager | Route 53 failover routing + health check | Both are DNS-based (TTL-bound) |
| Metrics | Managed Prometheus (DCR) | Amazon Managed Prometheus (managed collector) | Both agentless/managed options exist |
| Dashboards | Azure Managed Grafana | Grafana in cluster (AMG needs IAM Identity Center) | |
| Logs | Container Insights → Log Analytics (KQL) | Container Insights → CloudWatch Logs (Logs Insights) | |
| Alerts | Prometheus rule group → Action Group | AMP rules → Alertmanager → SNS | |
| Cost guardrail | Consumption budget | AWS Budgets | |
