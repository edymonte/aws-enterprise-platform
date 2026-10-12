#!/usr/bin/env bash
# CI equivalent of 'awp.ps1 bootstrap' outputs: writes .runtime/backend.hcl and
# .runtime/common.tfvars.json from pipeline variables (GitHub vars / ADO variable group).
set -euo pipefail

: "${TF_STATE_BUCKET:?}" "${AWS_REGION:?}" "${ALERT_EMAIL:?}" "${NAME_SUFFIX:?}"
OPERATOR_IP_RANGES="${OPERATOR_IP_RANGES:-[]}"   # JSON array, e.g. ["203.0.113.10/32"]

mkdir -p .runtime
cat > .runtime/backend.hcl <<EOF
bucket       = "${TF_STATE_BUCKET}"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOF

cat > .runtime/common.tfvars.json <<EOF
{
  "region": "${AWS_REGION}",
  "alert_email": "${ALERT_EMAIL}",
  "operator_ip_ranges": ${OPERATOR_IP_RANGES},
  "state_bucket": "${TF_STATE_BUCKET}",
  "state_region": "${AWS_REGION}",
  "name_suffix": "${NAME_SUFFIX}"
}
EOF
echo "runtime files written"
