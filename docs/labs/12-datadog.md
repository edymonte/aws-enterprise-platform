# Phase 12 — Datadog on EKS (4 h)

## 🎯 Goal

Same as the Azure twin's phase 12, on EKS: Operator + Agent via GitOps, APM via `dd-trace`, monitors/SLO/dashboard via Terraform — then compare with AMP + CloudWatch.

> Create the Datadog trial (14 days) at the start of this phase and note your **site** (US1, US5, EU, …).

## 🛠️ Steps

1. Store the API key in Secrets Manager (never in Git):

```powershell
$name = terraform -chdir=infra/terraform/30-data output -raw datadog_secret_name
aws secretsmanager put-secret-value --secret-id $name --secret-string '<api-key>'
./scripts/datadog-secret.ps1
```

2. Set `spec.global.site` in `gitops/platform/datadog/datadog-agent.yaml`, move the add-on into `gitops/apps/`, set `datadog.enabled: true` in both `envs/*/values.yaml` → PR → merge (see `gitops/addons/datadog/README.md`).
3. Monitoring as code:

```powershell
$env:DD_API_KEY = '<api-key>'; $env:DD_APP_KEY = '<app-key>'; $env:DD_HOST = 'https://api.datadoghq.com'
./scripts/awp.ps1 apply 70-datadog -Var 'notify_handles=["@you@example.com"]'
```

4. Chaos PR (`errorRate: "0.2"` in prod) and compare detection, root-cause depth and setup effort with phase 11.

## ✅ Checkpoint

- [ ] Cluster visible in Datadog; APM service `customer-portal-api` with `env:prod` / `env:dev`.
- [ ] Monitors and SLO created by Terraform; error-rate monitor fired during chaos.

## 🎤 Interview

1. How did you deploy the Datadog Agent and protect its API key on EKS?
2. AWS-native (CloudWatch/AMP) vs Datadog — how would you advise a client already on Datadog for Azure?
3. Why `DD_AGENT_HOST` pointing to the node-local Service instead of `hostPort`?
