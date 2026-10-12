# Phase 07 — GitOps and the first delivery (6 h)

📘 **SAA-C03:** D2 (ALB, decoupled delivery)

## 🎯 Goal

Argo CD installs the platform add-ons and the portal; the AWS Load Balancer Controller creates **one shared ALB** for dev and prod.

## 🧠 Concepts

```text
gitops/apps/ (watched by the root app)
├── aws-load-balancer-controller.yaml          wave -10  Helm, SA matches the Pod Identity association
├── secrets-store-csi-driver.yaml              wave -10  CSI driver (rotation every 2m)
├── secrets-store-csi-driver-provider-aws.yaml wave -9   AWS provider (ASCP), uses Pod Identity
├── aps-collector-rbac.yaml                    wave -10  RBAC for the AMP managed collector
├── kube-state-metrics.yaml                    wave -5
├── grafana.yaml                               (multi-source: chart + values from this repo)
├── portal-dev.yaml / portal-prod.yaml         chart + envs/<env>/*.yaml
```

- **IngressGroup**: both Ingresses use `group.name: mfs-portal` → one ALB with host rules (cost!). `load-balancer-name` makes its name deterministic so `50-edge` can find it with `data "aws_lb"`.
- **target-type ip**: the ALB sends traffic straight to pod IPs (VPC CNI), skipping NodePorts.

## 🛠️ Steps

1. Render values and merge them:

```powershell
./scripts/render-gitops-values.ps1
git switch -c chore/platform-values; git add gitops; git commit -m "chore(gitops): platform values"; git push -u origin HEAD
gh pr create --fill; gh pr merge --squash --delete-branch
```

2. Build and push images (Docker Desktop running; ECR tags are **immutable**):

```powershell
./scripts/build-images.ps1 -Tag v1.0.0
```

Set both tags to `v1.0.0` in `gitops/envs/dev/values.yaml` and `prod/values.yaml` → PR → merge.

3. Bootstrap Argo CD: `./scripts/bootstrap-gitops.ps1`
4. Create the DB user (runs `psql` from a pod inside the VPC): `./scripts/db-grant-app-user.ps1`
5. Test through the ALB before CloudFront exists (the ALB SG allows your IP):

```powershell
$alb = aws elbv2 describe-load-balancers --names alb-mfs-portal-lab --query "LoadBalancers[0].DNSName" --output text
curl.exe -s -H "Host: portal-dev.aws.edymonte.com.br" "http://$alb/api/info"
curl.exe -s -H "Host: portal-dev.aws.edymonte.com.br" "http://$alb/api/products"
```

`/api/info` should show `"database": "rds-postgres"` and the banner from Secrets Manager.

## ✅ Checkpoint

- [ ] All Argo CD apps `Synced/Healthy`.
- [ ] One ALB with rules for both hosts: `aws elbv2 describe-rules --listener-arn <arn>`.
- [ ] Update the banner secret → `/api/info` changes within ~2 min without restart.

## 💥 Break it

Remove the Pod Identity association for `portal-prod` in the console. **Observation:** prod pods fail `/readyz` (`CredentialsProviderError` / `PAM authentication failed`), dev is fine. **Diagnosis path:** pod logs → `aws eks list-pod-identity-associations` → re-apply `40-eks`. Note how Argo CD cannot fix it: the drift is on the **AWS** side, Terraform's job.

## 🎤 Interview

1. How does the AWS Load Balancer Controller decide which subnets to use? *(subnet tags from 10-network)*
2. target-type `ip` vs `instance`?
3. Why one ALB for two environments here, and why not in production?
4. How does a pod read a Secrets Manager secret as a file?
