# Technical questions — model answers (AWS)

Tags: **D1** secure, **D2** resilient, **D3** high-performing, **D4** cost-optimized (SAA-C03 domains).

## A. IAM and security

**1. Identity policy, resource policy, permissions boundary, SCP — how are they evaluated? (D1)**
An explicit deny anywhere wins. Otherwise the request must be allowed by the identity policy (or a resource policy for same-account access) **and** fit inside the permissions boundary **and** inside every SCP on the account path. Boundaries and SCPs never grant — they only cap.

**2. How do CI pipelines access AWS without keys? (D1)**
An IAM OIDC identity provider for the CI issuer and a role whose trust policy checks `aud` and `sub` (e.g. `repo:org/repo:environment:prod`). The job calls `AssumeRoleWithWebIdentity` and gets credentials for up to the role's session duration.

**3. How do you protect the root user and a new account? (D1)**
MFA on root, no root access keys, contact info and alternate contacts, IAM Identity Center for humans, CloudTrail org trail, GuardDuty, Config, budgets, S3 account public access block, EBS default encryption.

**4. KMS: AWS managed vs customer managed keys? (D1)**
AWS managed keys are free to hold and automatic but you can't control key policy or rotation. Customer managed keys give key policies, grants, rotation control and cross-account use, and cost $1/month each plus requests.

**5. Secrets Manager vs Parameter Store? (D1)**
Secrets Manager: rotation (native for RDS), cross-region replication, per-secret cost. Parameter Store: cheaper/free standard tier for configuration; SecureString with KMS; no native rotation.

## B. Networking

**6. What makes a subnet public? (D1)**
Its route table has a route to an internet gateway. Instances also need a public IP to be reachable.

**7. Security group vs NACL? (D1)**
SGs are stateful, allow-only, attached to ENIs, can reference other SGs and prefix lists. NACLs are stateless, ordered allow/deny rules at the subnet boundary — useful for explicit denies.

**8. NAT gateway resilience and cost? (D2/D4)**
A NAT gateway is zonal; for HA use one per AZ with per-AZ route tables. Cost is hourly plus per-GB; reduce it with gateway endpoints (S3/DynamoDB), interface endpoints for heavy AWS API use, and keeping traffic in-AZ.

**9. Gateway vs interface endpoints? (D1/D4)**
Gateway endpoints (S3, DynamoDB) are route-table targets and free. Interface endpoints are ENIs with private DNS (PrivateLink) for most services, billed per AZ-hour and per GB.

**10. Connecting many VPCs and on-premises? (D2)**
Transit Gateway as the hub (route tables for segmentation), Site-to-Site VPN or Direct Connect to on-premises, Route 53 Resolver endpoints for hybrid DNS. VPC peering is non-transitive and fine for a few VPCs.

**11. Route 53 routing policies? (D2)**
Simple; weighted (canary); latency (closest region); failover (active-passive with health checks); geolocation (compliance/content); geoproximity (bias traffic); multivalue (up to 8 healthy records).

**12. Alias vs CNAME? (D3)**
Alias is Route 53-specific, works at the zone apex, points to AWS resources (CloudFront, ALB, S3 website) and is free to query. CNAME cannot be at the apex.

## C. Compute and containers

**13. EKS vs ECS vs Fargate? (D3)**
EKS when you need Kubernetes portability/ecosystem; ECS for simpler AWS-native container orchestration; Fargate as serverless capacity for either when you don't want to manage nodes (trade-off: cost per vCPU, no DaemonSets on EKS Fargate).

**14. IRSA vs EKS Pod Identity? (D1)**
IRSA: per-cluster OIDC provider, role trust references it, SA annotation. Pod Identity: agent add-on + association API; trust is `pods.eks.amazonaws.com`, no annotations, reusable roles, session tags for ABAC.

**15. aws-auth vs access entries? (D1)**
Access entries manage cluster access through the EKS API with IAM principals and access policies; no ConfigMap that can be broken by a bad edit; auditable via CloudTrail.

**16. How do pods get IP addresses on EKS? Risks? (D2)**
The VPC CNI assigns secondary IPs from the node's subnet to pods. Risk: subnet exhaustion — mitigate with larger subnets, prefix delegation, or custom networking with a secondary CIDR.

**17. Scaling on EKS? (D2/D3)**
HPA for pods; Cluster Autoscaler or **Karpenter** for nodes (Karpenter provisions right-sized instances directly, handles Spot well). Set requests correctly; use PDBs and topology spread for resilience.

**18. ALB vs NLB? (D3)**
ALB: layer 7, host/path routing, WAF, OIDC auth, target-type ip for pods. NLB: layer 4, static IPs/EIPs, extreme throughput, TLS passthrough, PrivateLink endpoint services.

## D. Data

**19. RDS Multi-AZ vs read replicas vs Aurora? (D2)**
Multi-AZ: synchronous standby, automatic failover, no read scaling. Read replicas: asynchronous, read scaling, can be promoted, cross-region for DR. Aurora: storage replicated six ways across 3 AZs, fast failover, up to 15 replicas, Global Database.

**20. How does an app connect to RDS without a password? (D1)**
IAM database authentication (MySQL/PostgreSQL): the app signs a 15-minute token with its IAM credentials; the DB user is granted `rds_iam`; TLS required. Or RDS Proxy with IAM auth to the proxy.

**21. Backups and DR for RDS? (D2)**
Automated backups with PITR (retention up to 35 days), manual snapshots, cross-region snapshot copy or cross-region read replicas, AWS Backup for policy-based backups. Pick by RPO/RTO.

## E. Edge and delivery

**22. How do you secure an ALB behind CloudFront? (D1)**
SG allowing only the CloudFront origin-facing managed prefix list, plus a secret custom header validated by an ALB listener rule — or CloudFront VPC origins with an internal ALB. WAF at CloudFront.

**23. CloudFront origin failover vs Route 53 failover? (D2)**
Origin groups fail over per request on specified status codes (GET/HEAD) — fast, HTTP only. Route 53 failover is DNS-based, health-check driven, bounded by TTL and resolver caching.

**24. Blue/green and canary on AWS? (D2)**
Weighted target groups on an ALB, Route 53 weighted records, CodeDeploy for ECS/Lambda, Argo Rollouts on EKS. Always automate the rollback criteria (alarms/SLOs).

## F. Governance, observability, cost

**25. Preventive vs detective controls on AWS? (D1)**
Preventive: SCPs, permissions boundaries, account-level S3 block, resource policies. Detective: Config rules, Security Hub, GuardDuty, Access Analyzer, CloudTrail. Responsive: Config auto-remediation, EventBridge + Lambda.

**26. AWS Organizations and Control Tower — why? (D1)**
Multi-account strategy (isolation, blast radius, billing), SCPs, centralized logging/security accounts; Control Tower sets up a landing zone with guardrails and account vending.

**27. CloudWatch vs Managed Prometheus vs X-Ray? (D2)**
CloudWatch: AWS service metrics, logs, alarms, Container Insights. AMP: PromQL at scale for Kubernetes/app metrics. X-Ray (or ADOT): distributed tracing.

**28. Five quick wins to cut an AWS bill? (D4)**
Right-size and turn off idle/dev resources; Savings Plans/Reserved Instances for steady load; Spot for stateless/batch; reduce NAT data with endpoints; storage lifecycle (S3 tiers, gp3, snapshot cleanup); log retention.

**29. Spot instances — when and how? (D4)**
Stateless, fault-tolerant workloads; diversify instance types/AZs, capacity-optimized allocation, handle the 2-minute interruption notice (node termination handling, PDBs).

**30. Design question: "Highly available web app on AWS for a regulated client."**
Clarify RTO/RPO and compliance. Multi-account landing zone; VPC across 3 AZs; CloudFront + WAF → ALB → EKS/ECS across AZs; Aurora Multi-AZ with backups and cross-region snapshot copy; Secrets Manager + KMS CMKs; IAM roles only; Config/Security Hub/GuardDuty; CloudWatch alarms tied to SLOs; IaC with pipelines using OIDC and approvals. Close with the cost vs resilience trade-off you'd discuss.
