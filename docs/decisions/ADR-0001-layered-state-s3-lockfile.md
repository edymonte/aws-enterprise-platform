# ADR-0001 — Layered roots; S3 backend with native lock files

**Status:** accepted

## Context
Same layering rationale as the Azure twin (blast radius, cost control, ownership). Terraform ≥ 1.10 supports S3-native state locking.

## Decision
One state object per layer in one S3 bucket (versioned, SSE, TLS-only, public access blocked). Locking with `use_lockfile = true`; no DynamoDB table. `00-bootstrap` keeps local state.

## Consequences
- ✅ One fewer resource and IAM permission set (no DynamoDB).
- ✅ Lock file lives next to the state, covered by the same bucket policy.
- ⚠️ Requires Terraform ≥ 1.10 everywhere (pinned `>= 1.12.2`).

## Alternatives
DynamoDB lock table (legacy, still common in existing estates); Terraform Cloud/HCP remote state.
