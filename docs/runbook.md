# Runbook

## Daily cycle

```powershell
$env:AWS_PROFILE = 'mfs-lab'; aws sso login
./scripts/awp.ps1 up -Through 40-eks
./scripts/render-gitops-values.ps1                      # the ALB SG ID changes after recreating 40-eks → PR
./scripts/build-images.ps1 -Tag <new-tag>               # ECR repos are recreated empty; tags are immutable
aws secretsmanager put-secret-value --secret-id <banner_secret_name> --secret-string "..."
./scripts/bootstrap-gitops.ps1
./scripts/db-grant-app-user.ps1                         # the database is recreated empty
# ...
./scripts/awp.ps1 down                                  # removes Ingress/ALB before destroying EKS
```

Names stay stable across days (`name_suffix` from `00-bootstrap`); data does not (images, secrets, DB user).

## Common errors

| Error | Cause | Fix |
|---|---|---|
| `Error acquiring the state lock` | Crashed run left `<key>.tflock` | Confirm nobody runs, then `terraform -chdir=<layer> force-unlock <ID>` |
| `ExpiredToken` / `The SSO session has expired` | SSO token expired | `aws sso login` |
| `DependencyViolation` deleting the VPC | ALB/ENIs left by the LB Controller | Delete the ALB (`aws elbv2 delete-load-balancer`) and its target groups/SGs, then retry `destroy 10-network` |
| `kubectl` timeout | Your IP is not in `endpoint_public_access_cidrs` | Update `operatorIpRanges`, `bootstrap`, apply 10 and 40 |
| `Unauthorized` from kubectl | No access entry for your role | Apply 40-eks; check `aws eks list-access-entries` |
| Pods `CrashLoopBackOff` with `CredentialsProviderError` | Pod Identity association missing / agent not ready | `aws eks list-pod-identity-associations`; check `eks-pod-identity-agent` pods |
| `PAM authentication failed for user "portal_api"` | DB user not granted `rds_iam`, or IAM policy resource ARN mismatch | `db-grant-app-user.ps1`; check `db_resource_id` in the policy |
| ALB not created | LB Controller not running or subnets untagged | `kubectl -n kube-system logs deploy/aws-load-balancer-controller` |
| ACM certificate `PENDING_VALIDATION` | Delegation not live yet | `Resolve-DnsName aws.edymonte.com.br -Type NS -Server 8.8.8.8` |
| `CNAMEAlreadyExists` on CloudFront | Alias used by another distribution | Remove it from the other distribution first |
| `AccessDenied ... BlockPublicPolicy` | Account-level S3 block (by design) | Only for the DR lab: `allow_public_s3_website=true` in 20-governance |

## Full cleanup

```powershell
./scripts/awp.ps1 down
./scripts/awp.ps1 destroy 05-identity
terraform -chdir=infra/terraform/00-bootstrap destroy -var-file=../../../.runtime/bootstrap.tfvars.json
```

The state bucket has versioning: empty all object versions first (`aws s3api delete-objects` or the console's *Empty* button), or add `force_destroy = true` before the final destroy.
