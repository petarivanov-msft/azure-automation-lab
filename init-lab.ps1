#Requires -Version 5.1
<#
.SYNOPSIS
  Azure Automation Lab - Windows / PowerShell bootstrap (parity with init-lab.sh).

.DESCRIPTION
  Prompts for resource names, region, NSG source IP, and which scenarios to deploy,
  then runs `terraform init` / `plan` / `apply` from the terraform/ directory.

  Works in:
    - Windows PowerShell 5.1
    - PowerShell 7+ on Windows / macOS / Linux
    - Azure Cloud Shell (PowerShell)

.PARAMETER Upgrade
  Pass through `-upgrade` to `terraform init`. Off by default to keep the
  provider lock file stable.

.EXAMPLE
  iwr -useb https://raw.githubusercontent.com/petarivanov-msft/azure-automation-lab/main/init-lab.ps1 | iex

.EXAMPLE
  ./init-lab.ps1 -Upgrade
#>
[CmdletBinding()]
param(
  [switch]$Upgrade
)

$ErrorActionPreference = 'Stop'

function Write-Info($msg)    { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg)      { Write-Host $msg -ForegroundColor Green }
function Write-Warn2($msg)   { Write-Host $msg -ForegroundColor Yellow }
function Write-Err2($msg)    { Write-Host $msg -ForegroundColor Red }

function Read-WithDefault {
  param([string]$Prompt, [string]$Default)
  if ($Default) {
    $val = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($val)) { return $Default }
    return $val
  }
  do { $val = Read-Host $Prompt } while ([string]::IsNullOrWhiteSpace($val))
  return $val
}

function Register-AzProviderIfNeeded {
  param([string]$Namespace)
  $status = az provider show --namespace $Namespace --query "registrationState" -o tsv 2>$null
  if ($status -ne 'Registered') {
    Write-Info "Registering provider: $Namespace ..."
    az provider register --namespace $Namespace | Out-Null
    do {
      Start-Sleep -Seconds 5
      $status = az provider show --namespace $Namespace --query "registrationState" -o tsv
      Write-Info "Waiting for $Namespace ..."
    } while ($status -ne 'Registered')
    Write-Ok "Provider $Namespace registered."
  } else {
    Write-Ok "Provider $Namespace already registered."
  }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Blue
Write-Info  'Azure Automation Scenarios Lab'
Write-Host '========================================' -ForegroundColor Blue
Write-Host ''

# Pre-flight: az CLI + terraform must be on PATH.
foreach ($tool in 'az','terraform','git') {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    Write-Err2 "Required tool not found on PATH: $tool"
    Write-Err2 'Install Azure CLI, Terraform >= 1.9.0, and git, then re-run.'
    exit 1
  }
}

# Confirm az login.
$accountJson = az account show 2>$null
if (-not $accountJson) {
  Write-Warn2 'No active Azure CLI session detected. Running az login ...'
  az login | Out-Null
}

# Clone / refresh the repo.
if (-not (Test-Path 'azure-automation-lab')) {
  Write-Info 'Cloning repository...'
  git clone https://github.com/petarivanov-msft/azure-automation-lab.git
} else {
  Write-Info 'Updating existing repository...'
  Push-Location 'azure-automation-lab'
  git fetch origin
  git reset --hard origin/main
  Pop-Location
}
Set-Location 'azure-automation-lab'

# Defaults.
$ResourceGroup     = 'rg-automation-lab'
$Location          = 'uksouth'
$AutomationAccount = "auto-lab-$([int][double]::Parse((Get-Date -UFormat %s)))"
$VmAdminUsername   = 'azureadmin'

Write-Info 'Registering Azure providers...'
foreach ($ns in 'Microsoft.Automation','Microsoft.Compute','Microsoft.Network') {
  Register-AzProviderIfNeeded -Namespace $ns
}

Write-Host ''
Write-Info 'Configuration:'
Write-Host ''
$ResourceGroup     = Read-WithDefault 'Resource group name'     $ResourceGroup
$Location          = Read-WithDefault 'Azure region'            $Location
$AutomationAccount = Read-WithDefault 'Automation account name' $AutomationAccount
$VmAdminUsername   = Read-WithDefault 'VM admin username'       $VmAdminUsername

# Generate a strong VM password and pass via TF_VAR_* (never written to tfvars).
Write-Info 'Generating secure VM password...'
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
try {
  $VmAdminPassword = [System.Web.Security.Membership]::GeneratePassword(20, 4)
} catch {
  # Fallback for environments without System.Web (Linux PowerShell).
  $bytes = New-Object byte[] 16
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $VmAdminPassword = [Convert]::ToBase64String($bytes) + 'Aa1!'
}
$env:TF_VAR_vm_admin_password = $VmAdminPassword

# NSG source IP.
Write-Host ''
Write-Info 'Network access:'
Write-Host '  Lock RDP/WinRM/SSH to a specific source IP/CIDR (recommended).'
Write-Host '  Examples: 203.0.113.4/32  or  203.0.113.0/24'
Write-Host '  Type * to open to the public internet (lab-only).'
$AllowedSourceIp = ''
$AckOpenNsg      = 'false'
while ([string]::IsNullOrWhiteSpace($AllowedSourceIp)) {
  $AllowedSourceIp = Read-Host 'allowed_source_ip'
  if ($AllowedSourceIp -eq '*') {
    $confirm = Read-Host "'*' opens RDP/WinRM/SSH to the world. Type 'YES' to confirm"
    if ($confirm -ne 'YES') { $AllowedSourceIp = '' } else { $AckOpenNsg = 'true' }
  }
}

# Scenarios.
Write-Host ''
Write-Info 'Scenarios:'
Write-Host '  1) Runbooks (PowerShell 5.1, PowerShell 7.4, Python 3.10)'
Write-Host '  2) Hybrid Workers (Windows, Ubuntu, RHEL VMs)'
Write-Host '  3) Graph API Automation (requires elevated permissions)'
Write-Host ''
Write-Host '  a) Deploy ALL scenarios'
Write-Host '  n) Deploy NONE (core Automation Account only)'
Write-Host ''
$choice = Read-Host 'Selection (comma-separated for multiple, e.g. 1,2 or "a") [a]'
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 'a' }

$EnableRunbooks      = 'false'
$EnableHybridWorkers = 'false'
$EnableGraphApi      = 'false'
if ($choice -ieq 'a') {
  $EnableRunbooks = $EnableHybridWorkers = $EnableGraphApi = 'true'
} elseif ($choice -inotmatch '^n$') {
  foreach ($p in $choice -split ',') {
    switch ($p.Trim()) {
      '1' { $EnableRunbooks      = 'true' }
      '2' { $EnableHybridWorkers = 'true' }
      '3' { $EnableGraphApi      = 'true' }
      default { Write-Warn2 "Unknown scenario: $p (ignored)" }
    }
  }
}

Write-Host ''
Write-Info 'Scenarios to deploy:'
Write-Host ("  Runbooks (PS5.1/PS7.4/Python):  {0}" -f ($(if ($EnableRunbooks      -eq 'true'){'YES'}else{'NO'})))
Write-Host ("  Hybrid Workers (3 VMs):         {0}" -f ($(if ($EnableHybridWorkers -eq 'true'){'YES'}else{'NO'})))
Write-Host ("  Graph API:                      {0}" -f ($(if ($EnableGraphApi      -eq 'true'){'YES'}else{'NO'})))

# Write tfvars (password intentionally omitted).
Set-Location 'terraform'
Write-Info 'Writing terraform.tfvars (password supplied via TF_VAR_vm_admin_password env var)...'
$tfvars = @"
resource_group_name     = "$ResourceGroup"
location                = "$Location"
automation_account_name = "$AutomationAccount"
vm_admin_username       = "$VmAdminUsername"
# vm_admin_password supplied via TF_VAR_vm_admin_password env var

allowed_source_ip    = "$AllowedSourceIp"
acknowledge_open_nsg = $AckOpenNsg

enable_runbooks       = $EnableRunbooks
enable_hybrid_workers = $EnableHybridWorkers
enable_graph_api      = $EnableGraphApi
"@
$tfvars | Set-Content -Path 'terraform.tfvars' -Encoding utf8

Write-Info 'Initializing Terraform...'
$initArgs = @()
if ($Upgrade) { $initArgs += '-upgrade' }
terraform init @initArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Info 'Generating deployment plan...'
terraform plan -out tfplan
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
$confirm = Read-Host 'Deploy the lab environment? (yes/no)'
if ($confirm -inotin @('yes','y')) {
  Write-Warn2 'Deployment cancelled.'
  Remove-Item -Force tfplan -ErrorAction SilentlyContinue
  exit 0
}

Write-Info 'Deploying...'
Write-Warn2 'This will take approximately 15-25 minutes...'
terraform apply tfplan
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Persist password to a gitignored file for re-export.
$passwordFile = Join-Path (Get-Location) '.vm_admin.password'
$VmAdminPassword | Set-Content -Path $passwordFile -NoNewline -Encoding ascii
try {
  $acl = Get-Acl $passwordFile
  $acl.SetAccessRuleProtection($true, $false)
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
    'FullControl','Allow')
  $acl.AddAccessRule($rule)
  Set-Acl -Path $passwordFile -AclObject $acl
} catch {
  # ACL hardening only works on Windows; ignore on Linux/macOS.
}

Write-Host ''
Write-Ok 'Deployment complete.'
Write-Host ''
$ActualRG = terraform output -raw resource_group_name 2>$null
if (-not $ActualRG) { $ActualRG = $ResourceGroup }
Write-Info "Resource Group     : $ActualRG"
Write-Info "Location           : $Location"
Write-Info "Automation Account : $AutomationAccount"
Write-Host ''
Write-Host "VM credentials     : username=$VmAdminUsername"
Write-Host "VM password file   : $passwordFile (gitignored)"
Write-Host "Re-export with     : `$env:TF_VAR_vm_admin_password = Get-Content $passwordFile -Raw"
Write-Host ''
Write-Info 'Outputs: terraform output'
Write-Host ''
Write-Warn2 'Cleanup when done:'
Write-Host "  cd $(Get-Location)"
Write-Host '  terraform destroy -auto-approve'
