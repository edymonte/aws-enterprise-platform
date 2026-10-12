<#
.SYNOPSIS
  Creates the IAM-authenticated database user 'portal_api' in RDS PostgreSQL.

.DESCRIPTION
  RDS is private (no public access), so the one-off SQL runs from a short-lived
  pod INSIDE the VPC. The master password is read from Secrets Manager (managed
  by RDS) and handed to the pod through a temporary Kubernetes Secret that is
  deleted at the end — it never appears in Git, Terraform state or pod args.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

& (Join-Path $PSScriptRoot 'awp.ps1') init 40-eks | Out-Null
$o = (& terraform "-chdir=$(Join-Path $Root 'infra/terraform/40-eks')" output -json) | ConvertFrom-Json
$master = aws secretsmanager get-secret-value --secret-id $o.db_master_secret_arn.value --query SecretString --output text | ConvertFrom-Json

$sql = @'
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'portal_api') THEN
    CREATE USER portal_api;
  END IF;
END $$;
GRANT rds_iam TO portal_api;
GRANT CONNECT ON DATABASE portal TO portal_api;
GRANT USAGE, CREATE ON SCHEMA public TO portal_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO portal_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO portal_api;
'@

$ns = 'db-admin'
try {
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - | Out-Null
  kubectl -n $ns create secret generic pg-master `
    --from-literal=PGPASSWORD=$($master.password) --from-literal=PGUSER=$($master.username) | Out-Null

  Write-Host "==> running GRANTs on $($o.db_address.value) from a pod inside the VPC"
  $overrides = @{
    spec = @{
      containers = @(@{
          name    = 'psql'
          image   = 'postgres:16-alpine'
          command = @('psql', "host=$($o.db_address.value) dbname=portal sslmode=require", '-v', 'ON_ERROR_STOP=1', '-c', $sql)
          envFrom = @(@{ secretRef = @{ name = 'pg-master' } })
        })
    }
  } | ConvertTo-Json -Depth 10 -Compress
  kubectl -n $ns run psql --rm -i --restart=Never --image=postgres:16-alpine --overrides=$overrides
  if ($LASTEXITCODE -ne 0) { throw 'psql failed (check the RDS security group and that the cluster is up).' }
}
finally {
  kubectl delete namespace $ns --wait=false | Out-Null
}
