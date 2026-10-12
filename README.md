# AWS Enterprise Platform — guided lab

The AWS twin of [azure-enterprise-platform](https://github.com/edymonte/azure-enterprise-platform): a **simulated but real** production platform for the fictional company **Monteiro Financial Services**, built end to end with **Terraform**:

**EKS · GitOps (Argo CD) · AWS Config · GuardDuty · Security Hub · RDS PostgreSQL (IAM auth) · Secrets Manager · CloudFront + AWS WAF · Route 53 · Amazon Managed Prometheus · Grafana · Datadog · GitHub Actions · Azure DevOps**

> Start with **[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)**. Coming from Azure? Read **[docs/AZURE-AWS-MAPPING.md](docs/AZURE-AWS-MAPPING.md)**.

Every lab is tagged with the **AWS SAA-C03** domain it reinforces, so the hands-on work doubles as certification practice.

## How the lab works

| Section | What you do |
|---|---|
| 🎯 Goal | Understand the business requirement |
| 🧠 Concepts | The minimum Terraform + AWS theory |
| 🛠️ Steps | Run the commands, each one explained |
| ✅ Checkpoint | Prove it works |
| 💥 Break it | Diagnose an injected failure (Observation → Hypothesis → Test → Evidence) |
| 🎤 Interview | Answer without notes |
| 🏋️ Challenge | *(phase 04+)* write part of the Terraform; answer collapsed |
| 📘 SAA-C03 | Which exam domain the phase covers |

## Roadmap and time budget

| Phase | Lab | Layer / folder | SAA-C03 | Hours |
|---:|---|---|---|---:|
| 00 | [Prerequisites: account, tools, domain](docs/labs/00-prerequisites.md) | `config/` | — | 2 |
| 01 | [Bootstrap: S3 state, Route 53 zone, budget](docs/labs/01-bootstrap-state.md) | `00-bootstrap` | D1, D4 | 2 |
| 02 | [Identity: OIDC roles and permissions boundary](docs/labs/02-identity.md) | `05-identity` | D1 | 3 |
| 03 | [VPC across two AZs](docs/labs/03-network.md) | `10-network` | D1, D2, D4 | 4 |
| 04 | [Governance: Config, GuardDuty, Security Hub](docs/labs/04-governance.md) | `20-governance` | D1 | 4 |
| 05 | [Data: RDS with IAM auth, Secrets Manager](docs/labs/05-data.md) | `30-data` | D1, D2 | 4 |
| 06 | [EKS with Pod Identity](docs/labs/06-eks.md) | `40-eks` | D2, D3 | 6 |
| 07 | [GitOps + first delivery](docs/labs/07-gitops.md) | `gitops/` | D2 | 6 |
| 08 | [CI/CD with GitHub Actions](docs/labs/08-github-actions.md) | `.github/` | D1 | 3 |
| 09 | [CI/CD with Azure DevOps → AWS](docs/labs/09-azure-devops.md) | `pipelines/` | D1 | 4 |
| 10 | [Edge: CloudFront, WAF, Route 53 failover](docs/labs/10-edge.md) | `50-edge` | D2, D3 | 5 |
| 11 | [Observability: AMP, Grafana, Container Insights](docs/labs/11-observability.md) | `60-observability` | D2 | 4 |
| 12 | [Datadog on EKS](docs/labs/12-datadog.md) | `70-datadog` | — | 4 |
| 13 | [Game days](docs/game-days.md) | everything | all | 5 |
| 14 | [Portfolio and mock interview](docs/labs/14-portfolio.md) | `docs/` | — | 2 |
| | **Total** | | | **≈ 58 h** |

## Day-to-day commands

```powershell
$env:AWS_PROFILE = 'mfs-lab'; aws sso login
./scripts/awp.ps1 status
./scripts/awp.ps1 up -Through 40-eks
./scripts/bootstrap-gitops.ps1
./scripts/awp.ps1 down
```

## Documentation

- [How it works](docs/HOW-IT-WORKS.md) · [Azure ↔ AWS mapping](docs/AZURE-AWS-MAPPING.md) · [Costs](docs/costs.md) · [Runbook](docs/runbook.md)
- [Game days](docs/game-days.md) · [ADRs](docs/decisions/) · [Interview pack (AWS)](docs/interview/README.md) · [7-day personal route](docs/ROUTE-7-DAYS.md)
