# Partial backend configuration: scripts/awp.ps1 injects the S3 bucket created
# by 00-bootstrap and a per-layer state key (one state file per layer).
# Locking uses S3 native lock files (use_lockfile) — no DynamoDB table needed.
terraform {
  backend "s3" {}
}
