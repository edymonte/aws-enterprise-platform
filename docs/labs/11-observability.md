# Phase 11 — Observability: AMP, Grafana and Container Insights (4 h)

📘 **SAA-C03:** D2 (monitoring, SNS fan-out)

## 🎯 Goal

Golden signals in Grafana from Amazon Managed Prometheus (collected **without an agent**), container logs in CloudWatch, and an SLO alert by e-mail.

## 🧠 Concepts

```text
pods (prometheus.io/scrape) ─┐
kube-state-metrics ──────────┼─► AMP managed collector (ENIs in private subnets) ─► AMP workspace
cAdvisor via API proxy ──────┘          auth: EKS access entry "aps-collector-user" + RBAC (Argo CD)
AMP rule groups ─► Alertmanager ─► SNS topic (10-network) ─► e-mail
Grafana (Argo CD) ─SigV4, Pod Identity─► AMP query API
Container Insights add-on ─► CloudWatch Logs / metrics (Logs Insights queries)
```

## 🛠️ Steps

1. `./scripts/awp.ps1 apply 60-observability`
2. `./scripts/render-gitops-values.ps1` (now also writes the Grafana data source) → PR → merge.
3. Grafana: `kubectl -n grafana port-forward svc/grafana 3000:80`; password: `kubectl -n grafana get secret grafana -o jsonpath="{.data.admin-password}" | base64 -d`. Dashboard **MFS → Customer Portal — Golden Signals** (loaded from Git).
4. Traffic loop:

```powershell
1..600 | ForEach-Object { curl.exe -s -o NUL https://portal.aws.edymonte.com.br/api/products; Start-Sleep -Milliseconds 200 }
```

5. Logs Insights (*CloudWatch → Logs Insights*, group `/aws/containerinsights/eks-mfs-portal-lab/application`):

```text
fields @timestamp, kubernetes.pod_name, log
| filter kubernetes.namespace_name = "portal-prod" and log like /"level":"error"/
| sort @timestamp desc
| limit 50
```

6. Fire an SLO alert: `chaos.errorRate: "0.2"` in prod via PR → `PortalHighErrorRatio` → SNS e-mail. Revert.

## ✅ Checkpoint

- [ ] `aws amp list-scrapers` → `ACTIVE`; Grafana panels show data.
- [ ] Logs Insights finds the injected errors.
- [ ] Alert e-mail received.

## 💥 Break it

Delete the `aps-collector-rbac` Argo CD app's ClusterRoleBinding (`kubectl delete clusterrolebinding aps-collector-user-role-binding`). **Observation:** Argo CD re-creates it within seconds (self-heal). Now do it with auto-sync disabled for that app: dashboards go empty after a few scrapes. **Diagnosis:** the collector authenticates (access entry) but is not **authorized** (RBAC) — the same authN/authZ split as everywhere else.

## 🎤 Interview

1. Managed collector vs ADOT collector vs self-hosted Prometheus — trade-offs?
2. CloudWatch Container Insights vs Prometheus — what do you use each for?
3. How does Alertmanager deliver to SNS, and why does the topic need a resource policy?
