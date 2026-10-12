# Phase 06 — EKS with Pod Identity (6 h)

📘 **SAA-C03:** D2 (containers, multi-AZ), D3 (compute choices)

## 🎯 Goal

An EKS cluster built the current way: **access entries** instead of `aws-auth`, **Pod Identity** instead of IRSA, VPC CNI with **network policies**, immutable ECR, and an ALB security group locked to CloudFront.

## 🧠 Concepts — decisions inside `module "eks"` (v21)

| Input | Choice | Why |
|---|---|---|
| `authentication_mode = "API"` | access entries | Cluster access managed through the EKS API/IAM; no fragile `aws-auth` ConfigMap |
| `enable_cluster_creator_admin_permissions` | true | The identity running Terraform becomes cluster admin |
| `endpoint_public_access_cidrs` | your IP | Public endpoint, allow-listed (Config flags it — a conscious exception) |
| `addons.vpc-cni.configuration_values` | `enableNetworkPolicy` | NetworkPolicy enforced by the VPC CNI agent (eBPF) |
| `addons.eks-pod-identity-agent` | `before_compute` | The agent must exist before workloads need credentials |
| `eks_managed_node_groups.default` | AL2023, t3.medium, 1–3 | Managed lifecycle (drain/replace on upgrade) |
| `aws_eks_pod_identity_association` | (ns, SA) → role | The AWS side of workload identity — no annotations in Kubernetes |

## 🛠️ Steps

1. `./scripts/awp.ps1 apply 40-eks` (~15 min).
2. Access:

```powershell
aws eks update-kubeconfig --region us-east-1 --name eks-mfs-portal-lab
kubectl get nodes -o wide
aws eks list-access-entries --cluster-name eks-mfs-portal-lab
aws eks list-pod-identity-associations --cluster-name eks-mfs-portal-lab --output table
```

3. Notice pod IPs are **VPC IPs** from the private subnets: `kubectl get pods -A -o wide`.

## ✅ Checkpoint

- [ ] Nodes `Ready` in two AZs.
- [ ] Add-ons `ACTIVE`: `aws eks list-addons --cluster-name eks-mfs-portal-lab`.
- [ ] 4 Pod Identity associations (portal-dev, portal-prod, LB controller, CloudWatch).

## 💥 Break it — "kubectl suddenly Unauthorized"

Delete your access entry in the console (*EKS → Access → IAM access entries*). **Observation:** `You must be logged in to the server (Unauthorized)` — but `aws sts get-caller-identity` works. **Diagnosis:** authentication to AWS is fine; **authorization to Kubernetes** is the access entry. Fix by re-applying `40-eks` (the module re-creates it).

## 🏋️ Challenge — a `portal-qa` environment

<details><summary>Answer</summary>

One line: `portal_namespaces = ["portal-dev", "portal-qa", "portal-prod"]` → `for_each` adds one Pod Identity association. Then the GitOps side (Application + values) in phase 07.

</details>

## 🎤 Interview

1. IRSA vs EKS Pod Identity — how does each work and why prefer Pod Identity now?
2. access entries vs `aws-auth` ConfigMap?
3. Why do EKS pods consume VPC IPs, and how do you avoid IP exhaustion? *(larger subnets, prefix delegation, custom networking with secondary CIDR.)*
4. EKS vs ECS vs Fargate — how do you choose?
5. Managed node groups vs self-managed vs Karpenter?
