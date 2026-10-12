# Phase 10 — Edge: CloudFront, WAF and Route 53 failover (5 h)

📘 **SAA-C03:** D2 (Route 53 routing policies, health checks), D3 (CloudFront)

## 🎯 Goal

Serve `https://portal.aws.edymonte.com.br` and `https://portal-dev.aws.edymonte.com.br` through CloudFront with an ACM certificate and AWS WAF; lock the ALB to CloudFront; run a DNS failover to a static maintenance site in another region.

> 💰 Apply when you start the phase, destroy when done (`./scripts/awp.ps1 destroy 50-edge`).

## 🧠 Concepts

| Need | AWS answer | Detail in this layer |
|---|---|---|
| Global HTTPS entry | CloudFront | `Managed-CachingDisabled` + `Managed-AllViewer` (dynamic app, Host forwarded) |
| Certificate | ACM, **us-east-1** for CloudFront | DNS validation records created by Terraform in Route 53 |
| Web protection | AWS WAF web ACL, scope `CLOUDFRONT` | managed rule groups + rate-based rule; `count` → `block` |
| Origin lock | SG with prefix list `com.amazonaws.global.cloudfront.origin-facing` | + `X-Origin-Verify` custom header (challenge) |
| DNS failover | Route 53 failover routing + health check | Primary = CloudFront, secondary = S3 website in `sa-east-1` |

Two providers in one layer: `aws` (us-east-1) and `aws.dr` (sa-east-1) — see `50-edge/providers.tf`.

## 🛠️ Steps

1. Preconditions: delegation from phase 01 works; the ALB exists (phase 07).
2. `./scripts/awp.ps1 apply 50-edge` — ACM validation usually takes minutes; the CloudFront deployment ~5–10 min.
3. Test:

```powershell
curl.exe -sI https://portal.aws.edymonte.com.br                   # x-cache / via: CloudFront
curl.exe -s  https://portal-dev.aws.edymonte.com.br/api/info
curl.exe -s -o NUL -w "%{http_code}`n" "https://portal.aws.edymonte.com.br/api/products?id=1' OR '1'='1"   # count: 200
./scripts/awp.ps1 apply 50-edge -Var 'waf_mode=block'
curl.exe -s -o NUL -w "%{http_code}`n" "https://portal.aws.edymonte.com.br/api/products?id=1' OR '1'='1"   # block: 403
```

4. DR lab (needs the public-website exception — that is the point):

```powershell
./scripts/awp.ps1 apply 20-governance -Var 'allow_public_s3_website=true'
./scripts/awp.ps1 apply 50-edge -Var 'enable_dr_lab=true' -Var 'waf_mode=block'
Resolve-DnsName portal-dr.aws.edymonte.com.br -Server 8.8.8.8     # CloudFront IPs
```

   Make prod unhealthy **through GitOps**: `chaos.errorRate: "1"` in `gitops/envs/prod/values.yaml` → PR → merge. After ~1–2 min the health check fails and `portal-dr` resolves to the S3 website in São Paulo (`http://portal-dr.aws.edymonte.com.br` shows the maintenance page). Revert the PR, then remove the exception: `apply 50-edge` (DR off) and `apply 20-governance`.

## ✅ Checkpoint

- [ ] Both hosts HTTPS with a valid certificate; direct ALB access from another network times out.
- [ ] SQLi probe: 200 in `count`, 403 in `block`.
- [ ] Route 53 health check flips and the answer moves to the secondary.
- [ ] AWS Config flagged the public maintenance bucket while it existed.

## 🏋️ Challenge — verify the origin header at the ALB

The SG prefix list admits **any** CloudFront distribution. Make the ALB reject requests without `X-Origin-Verify`.

<details><summary>Answer</summary>

With the AWS Load Balancer Controller, add a condition annotation to the Ingress rules, e.g. in the chart:

```yaml
alb.ingress.kubernetes.io/conditions.customer-portal-api: >
  [{"field":"http-header","httpHeaderConfig":{"httpHeaderName":"X-Origin-Verify","values":["<value>"]}}]
```

(and the same for `customer-portal-web`), plus a default action returning 403. Better in production: **CloudFront VPC origins** — the ALB becomes internal and has no public exposure at all.

</details>

## 🎤 Interview

1. Route 53 routing policies: simple, weighted, latency, failover, geolocation, geoproximity, multivalue — one use case each.
2. Why must CloudFront's certificate be in us-east-1?
3. How do you make sure only CloudFront can reach your ALB?
4. CloudFront origin failover (origin groups) vs Route 53 failover — differences?
5. Alias vs CNAME records?
