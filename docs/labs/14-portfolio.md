# Phase 14 — Portfolio and mock interview (2 h)

1. **Screenshots** (`docs/images/`): Argo CD tree, Grafana dashboard, CloudFront + WAF metrics, Route 53 health check flip, Config compliance, Security Hub score.
2. **Multi-cloud story**: write a short section in the README comparing this platform with the Azure twin using [AZURE-AWS-MAPPING.md](../AZURE-AWS-MAPPING.md). Interviewers love candidates who can explain *differences*, not just services.
3. **ADR of your own**: document the `eks-endpoint-no-public-access` exception (why public + allow-list in the lab, what changes in production).
4. **3-minute demo video (English)**: PR → pipeline → Argo CD → chaos → SNS e-mail → Route 53 failover → revert.
5. **Mock interview**: [docs/interview/README.md](../interview/README.md).

## ✅ Checkpoint

- [ ] You can explain the request, identity, delivery and observability flows without notes.
- [ ] You can answer every 🎤 question from phases 01–12 in English, and map each to its Azure equivalent.
