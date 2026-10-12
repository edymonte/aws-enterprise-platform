<#
.SYNOPSIS
  One-time cluster bootstrap: kubeconfig, Argo CD install, app-of-apps.

.DESCRIPTION
  After this script, nobody runs kubectl apply / helm install for the platform
  or the app again: changes go through Git and Argo CD reconciles them.
#>
[CmdletBinding()]
param(
  [string]$ArgoChartVersion = '10.10.2'
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

& (Join-Path $PSScriptRoot 'awp.ps1') init 40-eks | Out-Null
$o = (& terraform "-chdir=$(Join-Path $Root 'infra/terraform/40-eks')" output -json) | ConvertFrom-Json

Write-Host "==> aws eks update-kubeconfig ($($o.cluster_name.value)) — access via EKS access entries (IAM)"
aws eks update-kubeconfig --region $o.region.value --name $o.cluster_name.value
kubectl get nodes -o wide

Write-Host '==> helm install argo-cd'
helm repo add argo https://argoproj.github.io/argo-helm --force-update | Out-Null
helm upgrade --install argocd argo/argo-cd --version $ArgoChartVersion `
  --namespace argocd --create-namespace `
  -f (Join-Path $Root 'gitops/bootstrap/argocd-values.yaml') --wait --timeout 10m

Write-Host '==> kubectl apply root app (app-of-apps)'
kubectl apply -f (Join-Path $Root 'gitops/bootstrap/root-app.yaml')

Write-Host @'

Argo CD UI:
  kubectl -n argocd port-forward svc/argocd-server 8080:80
  user: admin
  password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
'@
