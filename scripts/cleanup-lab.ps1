#Requires -Version 5.1
<#
.SYNOPSIS
  Destroy all lab resources. PowerShell mirror of scripts/cleanup-lab.sh.

.DESCRIPTION
  Run from the terraform/ directory or repo root.
  No jq dependency — uses `terraform state list` for the inventory preview.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Info($msg)   { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg)     { Write-Host $msg -ForegroundColor Green }
function Write-Warn2($msg)  { Write-Host $msg -ForegroundColor Yellow }
function Write-Err2($msg)   { Write-Host $msg -ForegroundColor Red }

Write-Info 'Azure Automation Lab - Cleanup'
Write-Host ''

if (Test-Path 'terraform.tfvars') {
  # already in terraform dir
} elseif (Test-Path '../terraform/terraform.tfvars') {
  Set-Location '../terraform'
} else {
  Write-Err2 'Error: terraform.tfvars not found.'
  Write-Warn2 'Run from the terraform directory or repo root.'
  exit 1
}

Write-Warn2 'WARNING: This will destroy all lab resources.'
Write-Host ''

if (Test-Path 'terraform.tfstate') {
  Write-Info 'Resources in state:'
  terraform state list 2>$null
  Write-Host ''
}

$confirm = Read-Host 'Destroy everything? (yes/no)'
if ($confirm -ne 'yes') {
  Write-Warn2 'Cancelled.'
  exit 0
}

Write-Host ''
Write-Info 'Destroying...'
terraform destroy -auto-approve
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host ''
Write-Ok 'Done. All resources removed.'
