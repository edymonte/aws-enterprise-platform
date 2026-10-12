# Architecture decision records

| ADR | Decision |
|---|---|
| [0001](ADR-0001-layered-state-s3-lockfile.md) | Layered Terraform roots; S3 backend with native lock files |
| [0002](ADR-0002-pod-identity-over-irsa.md) | EKS Pod Identity instead of IRSA |
| [0003](ADR-0003-community-modules-for-vpc-eks.md) | Community modules for VPC and EKS, raw resources elsewhere |
| [0004](ADR-0004-single-nat-two-azs.md) | Two AZs with a single NAT gateway (lab) |
| [0005](ADR-0005-cloudfront-public-alb-origin.md) | CloudFront with a public ALB origin locked by prefix list |
| [0006](ADR-0006-rds-postgres-iam-auth.md) | RDS PostgreSQL with IAM authentication (not SQL Server) |

The GitOps, CI-opens-PRs, dual-observability and one-cluster decisions are the same as in the Azure twin's ADR-0002, 0003, 0006 and 0007.
