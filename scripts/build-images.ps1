<#
.SYNOPSIS
  Builds and pushes the API and web images to ECR (first deploy, before CI exists).
  Requires Docker Desktop. Tags are IMMUTABLE in ECR: use a new tag every time.
#>
[CmdletBinding()]
param(
  [string]$Tag = "manual-$(Get-Date -Format 'yyyyMMddHHmm')"
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

& (Join-Path $PSScriptRoot 'awp.ps1') init 40-eks | Out-Null
$o = (& terraform "-chdir=$(Join-Path $Root 'infra/terraform/40-eks')" output -json) | ConvertFrom-Json
$registry = $o.ecr_registry.value

aws ecr get-login-password --region $o.region.value | docker login --username AWS --password-stdin $registry
foreach ($component in 'api', 'web') {
  $image = "$registry/customer-portal-${component}:$Tag"
  docker build --platform linux/amd64 -t $image (Join-Path $Root "app/customer-portal/$component")
  docker push $image
}
Write-Host "`nSet image.api.tag and image.web.tag to '$Tag' in gitops/envs/dev/values.yaml and open a PR."
