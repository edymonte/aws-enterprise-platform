# Phase 01 — Bootstrap: S3 state, Route 53 zone, budget (2 h)

📘 **SAA-C03:** D1 (S3 security), D4 (cost controls)

## 🎯 Goal

Create the long-lived pieces: the S3 bucket that holds every layer's state, the hosted zone `aws.edymonte.com.br`, and a budget.

## 🧠 Concepts

- **S3 state hardening** — every control is a separate resource in AWS provider v4+: ownership controls (ACLs off), public access block, versioning, SSE, lifecycle (expire old versions), bucket policy denying non-TLS.
- **Locking** — `use_lockfile = true` writes `<key>.tflock` next to the state with a conditional write. No DynamoDB table.
- **Subdomain delegation** — `edymonte.com.br` is (or will be) hosted elsewhere (Azure DNS in the twin lab, or Registro.br). We delegate only `aws.edymonte.com.br` to Route 53 with an **NS record in the parent zone**. Multi-cloud DNS in one sentence.

## 🛠️ Steps

1. Read `infra/terraform/00-bootstrap/main.tf`. Why is `aws_s3_bucket_policy` denying `aws:SecureTransport = false`?
2. Apply:

```powershell
./scripts/awp.ps1 bootstrap
```

3. Delegate the subdomain. The script prints 4 Route 53 name servers. In the parent zone:

   - **Parent in Azure DNS** (twin lab):
     ```powershell
     az network dns record-set ns create -g rg-mfs-dns -z edymonte.com.br -n aws --ttl 3600
     # repeat for each of the 4 name servers:
     az network dns record-set ns add-record -g rg-mfs-dns -z edymonte.com.br -n aws -d ns-123.awsdns-45.com
     ```
     (Better: add an `azurerm_dns_ns_record` to the Azure repo's 00-bootstrap — a nice cross-repo exercise.)
   - **Parent still at Registro.br**: Registro.br delegates whole domains only. Either host `edymonte.com.br` in Route 53 instead (set `publicZoneName` to `edymonte.com.br`), or do the Azure lab's phase 01 first.

4. Verify: `Resolve-DnsName aws.edymonte.com.br -Type NS -Server 8.8.8.8`.

## ✅ Checkpoint

- [ ] `aws s3api get-bucket-versioning --bucket <state_bucket>` → `Enabled`.
- [ ] Delegation resolves to `awsdns` servers.
- [ ] Budget visible in *Billing → Budgets*.

## 💥 Break it

Run two plans of the same layer at once (after phase 03 exists) from two terminals with `-lock=true`. **Observation:** the second fails with `Error acquiring the state lock`. **Evidence:** a `10-network.tfstate.tflock` object in the bucket. **Lesson:** locking is per state key — another reason for one state per layer.

## 🎤 Interview

1. How does Terraform lock state on S3 today, and how did it work before?
2. Which S3 controls protect a state bucket, and which one stops an accidental public policy?
3. How do you delegate a subdomain to Route 53 while the parent zone stays in another provider?
