# ADR-0003 — Community modules for VPC and EKS

**Status:** accepted

## Decision
Use `terraform-aws-modules/vpc/aws` (~> 6.7) and `terraform-aws-modules/eks/aws` (~> 21.0); write everything else as raw resources.

## Consequences
- ✅ Battle-tested defaults (launch templates, IMDSv2 hop limit, SG rules, add-on ordering) and what most AWS consulting teams use.
- ⚠️ Major upgrades rename inputs (v20 → v21: `cluster_name` → `name`, `cluster_addons` → `addons`, …). Pin versions, read changelogs, upgrade in a dedicated PR with a plan review.
- ⚠️ Less visibility into individual resources — `terraform state list` after apply is a good learning exercise.

## Alternatives
Raw resources everywhere (maximum control, much more code); AWS-provided blueprints (EKS Blueprints) — opinionated, heavier.
