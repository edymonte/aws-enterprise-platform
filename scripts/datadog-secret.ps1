<#
.SYNOPSIS
  Creates the Kubernetes secret with the Datadog API key — read from Secrets Manager.

.DESCRIPTION
  Store the key ONCE (never in Git, never in Terraform state):
    aws secretsmanager put-secret-value --secret-id <datadog_secret_name> --secret-string <key>
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

& (Join-Path $PSScriptRoot 'awp.ps1') init 40-eks | Out-Null
$name = ((& terraform "-chdir=$(Join-Path $Root 'infra/terraform/40-eks')" output -json) | ConvertFrom-Json).datadog_secret_name.value

$apiKey = aws secretsmanager get-secret-value --secret-id $name --query SecretString --output text
if (-not $apiKey) { throw "Secret '$name' has no value yet." }

kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -
kubectl -n datadog create secret generic datadog-secret --from-literal=api-key=$apiKey --dry-run=client -o yaml | kubectl apply -f -
Write-Host 'datadog-secret created/updated in namespace datadog.'
