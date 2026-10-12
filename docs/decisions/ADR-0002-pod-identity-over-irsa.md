# ADR-0002 — EKS Pod Identity instead of IRSA

**Status:** accepted

## Context
Pods need AWS credentials (RDS IAM auth, Secrets Manager, LB Controller, CloudWatch agent, Grafana → AMP).

## Decision
EKS Pod Identity: the `eks-pod-identity-agent` add-on plus `aws_eks_pod_identity_association` (cluster, namespace, service account → role). Roles trust `pods.eks.amazonaws.com`.

## Consequences
- ✅ No ServiceAccount annotations; no per-cluster OIDC provider in trust policies; roles reusable across clusters.
- ✅ Session tags (cluster, namespace, SA) available for ABAC.
- ⚠️ Requires SDKs recent enough to read the container credentials endpoint (all current SDKs do).
- ⚠️ Some third-party tools still document only IRSA.

## Alternatives
IRSA (OIDC provider + `sts:AssumeRoleWithWebIdentity`) — still valid and required for some cases (e.g. Fargate pods); node instance profile — too broad.
