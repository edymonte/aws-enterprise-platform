# 7-day personal route — AWS for a multi-cloud DevOps profile

Built with the **"personal route architect"** prompt:

> My goal is **to answer "what about AWS?" confidently in a multi-cloud DevOps interview and progress on SAA-C03**: to **explain the AWS twin of my Azure platform and 10 Azure ↔ AWS differences in English, and score ≥ 75% on SAA-C03 practice questions for domains 1 (secure) and 2 (resilient)** within **7 days** — not to learn AWS in general.
> I already master **Azure DevOps, GitHub Actions (GH-200), Terraform, Azure platform concepts, and SAA-C03 study basics (EC2, IAM fundamentals)**.
> Build a 7-day route with one daily task of **at most 45 minutes**, a success criterion, and what NOT to do. Redo it until it leads to the goal.

## Rules of the route

- **45 minutes, timer on.** Stop when it rings; log what was left.
- **Exam questions under exam conditions:** ~2 minutes per question, no notes, then review **every** wrong answer (why the right one is right *and* why yours is wrong).
- **Hands-on only where it pays off:** one cheap session (day 3). No EKS, NAT or CloudFront deployments in this route — they cost money and time that the goal does not need.
- **Mistakes log:** every wrong practice question goes to your SAA-C03 mistakes file with the rule you missed.
- **Re-plan rule:** a failed criterion is redone in the first 15 minutes of the next day; day 7 produces the gap list for the next route.

## The route

| Day | Task (≤ 45 min) | Success criterion | Don't |
|---:|---|---|---|
| 1 | **Mapping.** Read `docs/AZURE-AWS-MAPPING.md` (15 min). Pick 10 rows and explain each difference out loud, "in Azure… in AWS… it matters because…" (30 min). | **8 of 10** differences explained with *why it matters* (cost, security, resilience), in English, ≤ 45 s each. | Don't recite service names without the "why". Don't try to cover every row. |
| 2 | **IAM (D1).** Read `05-identity/main.tf` and lab 02 concepts (15 min). Whiteboard the policy evaluation order (identity ∩ boundary ∩ SCP, explicit deny wins) (10 min). 10 D1 practice questions on IAM/federation (20 min). | Evaluation logic drawn correctly from memory; can explain the **CreateRole escalation gap**; **≥ 7/10** questions. | Don't memorize managed policy names. Don't read IAM docs end to end. |
| 3 | **Cheap hands-on.** `aws sso login`, `./scripts/awp.ps1 bootstrap` (S3 state + Route 53 zone + budget), then `./scripts/awp.ps1 plan 10-network` and read the plan (no apply). | State bucket exists with versioning; you can point to the **`.tflock`** behaviour and explain **3 resources** of the network plan (route tables, NAT, endpoint). Cost of the day ≈ cents. | Don't `apply` 10-network or anything beyond. Don't debug SSO for more than 15 min — fall back to reading the plan in the lab doc. |
| 4 | **VPC & DNS (D1/D2).** Lab 03 concepts + Route 53 routing policies (15 min). 10 practice questions: subnets, NAT, endpoints, SG vs NACL, Route 53 (25 min). Review mistakes (5 min). | **≥ 7/10**; can explain gateway vs interface endpoint cost and NAT per AZ in ≤ 60 s. | Don't study Direct Connect/VPN details yet. Don't redraw the whole VPC. |
| 5 | **Compute, containers, data (D2/D3).** Answers C13–C18 and D19–D21 out loud (25 min). 10 practice questions on Multi-AZ vs read replicas, Auto Scaling, ALB vs NLB (20 min). | **≥ 7/10**; Pod Identity vs IRSA and Multi-AZ vs read replica each explained in ≤ 60 s. | Don't go deep on Kubernetes internals — the exam tests AWS choices. |
| 6 | **Edge & resilience (D2).** Lab 10 concepts (10 min). Design question F30 out loud, timed (10 min). 10 practice questions: CloudFront, Route 53 failover, backups/DR (RTO/RPO) (25 min). | Design answer starts with **clarifying questions** and ends with a **trade-off**; **≥ 7/10** questions. | Don't memorize CloudFront price classes or WAF rule names. |
| 7 | **Mock.** 15 mixed D1/D2 practice questions under exam timing (30 min). 2-minute multi-cloud pitch from `docs/interview/01-pitch.md` (5 min). Gap list (10 min). Then `terraform -chdir=infra/terraform/00-bootstrap destroy` if you won't continue soon. | **≥ 75% (12/15)**; pitch ≤ 2:15 with at least 2 Azure↔AWS differences; gap list ≤ 3 items. | Don't start a new topic. Don't leave resources running. |

## Redo loop (until the goal)

1. Each gap → a 45-minute task with a criterion.
2. Repeat days with failed criteria before moving on; keep the mistakes log growing — it is the real study material.
3. Ask the assistant: *"Redo the AWS route with these gaps and scores: …"* until day 7 passes twice in a row.
4. After that, the full lab (phases 05–13) becomes the deeper, hands-on route.

## Daily log

| Day | Score / criterion | What failed | Redo tomorrow? |
|---:|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |
| 7 | | | |
