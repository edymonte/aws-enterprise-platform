<#
.SYNOPSIS
  Lifecycle of the layered Terraform platform (AWS Enterprise Platform lab).

.DESCRIPTION
  Every Terraform command is PRINTED before it runs, so you can learn the exact
  commands and run them by hand later. Nothing here is magic: the script only
  adds the backend configuration and the shared variables for you.

  AWS credentials come from your normal CLI setup (e.g. $env:AWS_PROFILE with
  IAM Identity Center: aws configure sso / aws sso login).

.EXAMPLE
  ./scripts/awp.ps1 bootstrap                 # 00-bootstrap (local state) + .runtime files
  ./scripts/awp.ps1 plan 10-network           # init + plan one layer
  ./scripts/awp.ps1 apply 10-network          # plan, confirm, apply
  ./scripts/awp.ps1 up -Through 40-eks        # apply 05 -> 40 in order
  ./scripts/awp.ps1 down                      # destroy 70 -> 10 (keeps 00 and 05)
  ./scripts/awp.ps1 apply 50-edge -Var 'waf_mode=block'
  ./scripts/awp.ps1 status
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)]
  [ValidateSet('bootstrap', 'init', 'plan', 'apply', 'destroy', 'output', 'up', 'down', 'status')]
  [string]$Command,

  [Parameter(Position = 1)]
  [string]$Layer,

  [string]$Through = '40-eks',

  [string[]]$Var = @(),

  [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$TfRoot = Join-Path $Root 'infra/terraform'
$Runtime = Join-Path $Root '.runtime'
$SettingsFile = Join-Path $Root 'config/lab.settings.json'
$BackendFile = Join-Path $Runtime 'backend.hcl'
$CommonVars = Join-Path $Runtime 'common.tfvars.json'

# Order matters: each layer reads the outputs of the previous ones.
$Layers = @('05-identity', '10-network', '20-governance', '30-data', '40-eks', '50-edge', '60-observability', '70-datadog')
# 'down' keeps 00-bootstrap (state, hosted zone, budget) and 05-identity (free, slow to re-trust).
$DailyLayers = $Layers | Where-Object { $_ -ne '05-identity' }

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }

function Invoke-Tf([string]$Dir, [string[]]$Arguments) {
  $rel = [IO.Path]::GetRelativePath($Root, $Dir)
  Write-Host "    terraform -chdir=$rel $($Arguments -join ' ')" -ForegroundColor DarkGray
  & terraform "-chdir=$Dir" @Arguments
  if ($LASTEXITCODE -ne 0) { throw "terraform $($Arguments[0]) failed in $rel (exit $LASTEXITCODE)" }
}

function Get-Settings {
  if (-not (Test-Path $SettingsFile)) {
    throw "Missing $SettingsFile. Copy config/lab.settings.example.json and fill it in (docs/labs/00-prerequisites.md)."
  }
  Get-Content $SettingsFile -Raw | ConvertFrom-Json
}

function Assert-AwsLogin {
  $who = aws sts get-caller-identity --output json 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Not authenticated to AWS. Run: aws sso login (or set AWS_PROFILE).' }
  $id = $who | ConvertFrom-Json
  Write-Host "    AWS identity: $($id.Arn) (account $($id.Account))" -ForegroundColor DarkGray
}

function Assert-Layer([string]$Name) {
  if (-not $Name) { throw "Layer is required. Valid: $($Layers -join ', ')" }
  if ($Layers -notcontains $Name) { throw "Unknown layer '$Name'. Valid: $($Layers -join ', ')" }
  if ($Name -eq '70-datadog' -and -not ($env:DD_API_KEY -and $env:DD_APP_KEY)) {
    throw '70-datadog needs DD_API_KEY, DD_APP_KEY (and DD_HOST if your site is not US1) in the environment.'
  }
}

function Get-VarArgs([string]$Dir) {
  $result = @("-var-file=$CommonVars")
  $local = Join-Path $Dir 'terraform.tfvars'
  if (Test-Path $local) { $result += "-var-file=$local" }
  foreach ($v in $Var) { $result += "-var=$v" }
  return $result
}

function Initialize-Layer([string]$Name) {
  if (-not (Test-Path $BackendFile)) { throw 'Run "./scripts/awp.ps1 bootstrap" first (.runtime/backend.hcl is missing).' }
  $dir = Join-Path $TfRoot $Name
  Write-Step "init $Name (state key: $Name.tfstate)"
  Invoke-Tf $dir @('init', '-input=false', '-reconfigure', "-backend-config=$BackendFile", "-backend-config=key=$Name.tfstate")
  return $dir
}

function Confirm-Apply([string]$What) {
  if ($AutoApprove) { return $true }
  $answer = Read-Host "Apply $What? [y/N]"
  return $answer -match '^[Yy]$'
}

# The ALB is created by the AWS Load Balancer Controller (not Terraform). If the
# cluster is destroyed while Ingresses exist, the ALB and its ENIs are orphaned
# and block the VPC deletion in 10-network. So, before destroying 40-eks:
#   1. stop Argo CD from re-creating things (delete Applications, no cascade),
#   2. delete every Ingress so the controller deletes the ALB,
#   3. wait until the ALB is really gone.
function Remove-ClusterLoadBalancers([string]$Dir) {
  $o = (& terraform "-chdir=$Dir" output -json 2>$null) | ConvertFrom-Json
  if (-not $o.cluster_name) { return }
  Write-Step "pre-destroy: removing load balancers created from inside $($o.cluster_name.value)"
  aws eks update-kubeconfig --region $o.region.value --name $o.cluster_name.value | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host '    cluster not reachable, skipping'; return }
  kubectl delete applications.argoproj.io --all -n argocd --wait=false 2>$null | Out-Null
  kubectl delete ingress --all --all-namespaces --wait=true --timeout=3m
  $alb = $o.alb_name.value
  foreach ($i in 1..30) {
    aws elbv2 describe-load-balancers --names $alb --region $o.region.value *> $null
    if ($LASTEXITCODE -ne 0) { Write-Host "    ALB $alb deleted"; return }
    Start-Sleep -Seconds 10
  }
  Write-Warning "ALB $alb still exists; delete it manually before destroying 10-network."
}

function Invoke-Layer([string]$Name, [string]$Action) {
  Assert-Layer $Name
  $dir = Initialize-Layer $Name
  New-Item -ItemType Directory -Force (Join-Path $Runtime 'plans') | Out-Null
  $plan = Join-Path $Runtime "plans/$Name.tfplan"
  $varArgs = Get-VarArgs $dir

  switch ($Action) {
    'init' { return }
    'output' { Invoke-Tf $dir @('output'); return }
    'plan' {
      Write-Step "plan $Name"
      Invoke-Tf $dir (@('plan', '-input=false', "-out=$plan") + $varArgs)
    }
    'apply' {
      Write-Step "plan $Name"
      Invoke-Tf $dir (@('plan', '-input=false', "-out=$plan") + $varArgs)
      if (Confirm-Apply $Name) {
        Write-Step "apply $Name"
        Invoke-Tf $dir @('apply', '-input=false', $plan)
      } else { Write-Host "Skipped. Reviewed plan kept at $plan" }
    }
    'destroy' {
      if ($Name -eq '40-eks') { Remove-ClusterLoadBalancers $dir }
      Write-Step "plan -destroy $Name"
      Invoke-Tf $dir (@('plan', '-destroy', '-input=false', "-out=$plan") + $varArgs)
      if (Confirm-Apply "DESTROY of $Name") {
        Invoke-Tf $dir @('apply', '-input=false', $plan)
      } else { Write-Host 'Destroy cancelled.' }
    }
  }
}

function Invoke-Bootstrap {
  $s = Get-Settings
  Assert-AwsLogin
  $dir = Join-Path $TfRoot '00-bootstrap'
  New-Item -ItemType Directory -Force $Runtime | Out-Null

  $bootstrapVars = Join-Path $Runtime 'bootstrap.tfvars.json'
  @{
    region             = $s.region
    alert_email        = $s.alertEmail
    public_zone_name   = $s.publicZoneName
    monthly_budget_usd = $s.monthlyBudgetUsd
  } | ConvertTo-Json | Set-Content $bootstrapVars -Encoding utf8

  Write-Step '00-bootstrap uses LOCAL state (it creates the remote state bucket)'
  Invoke-Tf $dir @('init', '-input=false')
  Invoke-Tf $dir @('plan', '-input=false', "-var-file=$bootstrapVars", '-out=bootstrap.tfplan')
  if (-not (Confirm-Apply '00-bootstrap')) { return }
  Invoke-Tf $dir @('apply', '-input=false', 'bootstrap.tfplan')
  Remove-Item (Join-Path $dir 'bootstrap.tfplan') -ErrorAction SilentlyContinue

  $o = (& terraform "-chdir=$dir" output -json) | ConvertFrom-Json

  Write-Step 'Writing .runtime/backend.hcl (shared remote-state settings)'
  @"
bucket       = "$($o.state_bucket.value)"
region       = "$($o.region.value)"
encrypt      = true
use_lockfile = true
"@ | Set-Content $BackendFile -Encoding utf8

  Write-Step 'Writing .runtime/common.tfvars.json (variables shared by every layer)'
  @{
    region             = $s.region
    alert_email        = $s.alertEmail
    operator_ip_ranges = @($s.operatorIpRanges)
    github_repository  = $s.githubRepository
    state_bucket       = $o.state_bucket.value
    state_region       = $o.region.value
    zone_name          = $o.zone_name.value
    name_suffix        = $o.name_suffix.value
  } | ConvertTo-Json | Set-Content $CommonVars -Encoding utf8

  Write-Step "Delegate $($o.zone_name.value) from the parent zone with an NS record pointing to:"
  $o.zone_name_servers.value | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
}

function Show-Status {
  foreach ($name in $Layers) {
    $dir = Join-Path $TfRoot $name
    try {
      & terraform "-chdir=$dir" init -input=false -reconfigure "-backend-config=$BackendFile" "-backend-config=key=$name.tfstate" *> $null
      $count = @(& terraform "-chdir=$dir" state list 2>$null).Count
    } catch { $count = 0 }
    $label = if ($count -gt 0) { "DEPLOYED ($count resources)" } else { 'empty' }
    Write-Host ('{0,-18} {1}' -f $name, $label)
  }
}

switch ($Command) {
  'bootstrap' { Invoke-Bootstrap }
  'status' { Show-Status }
  'up' {
    $stop = [array]::IndexOf($Layers, $Through)
    if ($stop -lt 0) { throw "Unknown layer '$Through'" }
    foreach ($name in $Layers[0..$stop]) { Invoke-Layer $name 'apply' }
  }
  'down' {
    $reverse = [array]$DailyLayers
    [array]::Reverse($reverse)
    foreach ($name in $reverse) {
      if ($name -eq '70-datadog' -and -not $env:DD_API_KEY) { Write-Host 'Skipping 70-datadog (no DD_API_KEY).'; continue }
      Invoke-Layer $name 'destroy'
    }
  }
  default { Invoke-Layer $Layer $Command }
}
