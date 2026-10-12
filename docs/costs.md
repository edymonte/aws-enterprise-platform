# Costs and account limits

> Approximate `us-east-1` on-demand prices for orientation only — **confirm in the [AWS Pricing Calculator](https://calculator.aws/)**.

## Hourly drivers (when the platform is up)

| Item | Layer | Approx. | Note |
|---|---|---|---|
| EKS control plane | `40-eks` | ~$0.10/h | Billed even with zero nodes — destroy daily |
| 2 × t3.medium nodes | `40-eks` | ~$0.08/h | `node_capacity_type=SPOT` cuts this ~60–70% |
| NAT gateway | `10-network` | ~$0.045/h + data | One per VPC in the lab; per AZ in production |
| ALB | LB Controller | ~$0.023/h + LCU | Created by the Ingress; disappears when Argo CD apps are removed |
| RDS db.t4g.micro | `30-data` | free tier eligible | Otherwise ~$0.016/h |
| Interface endpoints | `10-network` | ~$0.01/h **each per AZ** | Off by default |
| CloudFront + WAF | `50-edge` | WAF ~$5/month per web ACL + $1/rule, prorated | Destroy after phase 10 |
| AMP | `60-observability` | per sample ingested + collector per hour | Small at lab scale |
| GuardDuty / Security Hub | `20-governance` | 30-day free trial | Disable afterwards (`enable_threat_detection=false`) |
| Route 53 zone + health check | `00` / `50` | $0.50/month + ~$0.50/month | |

A full day (8 h) with phases up to 40 is roughly **$2–3**; adding edge and observability, **$3–5**.

## Account pitfalls

1. **New accounts and the Free plan**: accounts created on the Free plan get promotional credits but may restrict some services. If a service is blocked, upgrade to the Paid plan (unused credits carry over).
2. **`down` must remove the ALB first**: the ALB is created by the Load Balancer Controller, not Terraform. If you destroy `40-eks` while the Ingress exists, the ALB and its ENIs can block the VPC deletion. The runbook's `down` order handles it: delete the Argo CD apps first (or `kubectl delete ingress -A --all`).
3. **NAT gateway** is the classic forgotten cost — it is in `10-network`, destroyed by `down`.
4. **CloudWatch Logs** from EKS control-plane logs and flow logs: retention is set; still check *Billing → Bills* weekly.
