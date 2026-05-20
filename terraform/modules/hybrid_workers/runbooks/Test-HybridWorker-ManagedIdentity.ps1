<#
.SYNOPSIS
    Validates hybrid worker connectivity using managed identity

.NOTES
    Runtime: PowerShell 5.1 / 7.x
    Requires: Az.Accounts, Az.Compute
#>

param()

Write-Output "Test-HybridWorker-ManagedIdentity"
Write-Output "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"
Write-Output "PowerShell: $($PSVersionTable.PSVersion)"
Write-Output "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Output ""

# Connect
try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    $context = Get-AzContext
    Write-Output "Connected OK"
    Write-Output "  Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    Write-Output "  Tenant: $($context.Tenant.Id)"
    Write-Output ""
} catch {
    Write-Error "Auth failed: $_"
    throw
}

# VMs
try {
    $vms = Get-AzVM
    Write-Output "$($vms.Count) VM(s) in subscription:"
    foreach ($vm in $vms) {
        Write-Output "  $($vm.Name) | $($vm.ResourceGroupName) | $($vm.HardwareProfile.VmSize) | $($vm.StorageProfile.OsDisk.OsType)"
    }
    Write-Output ""
} catch {
    Write-Error "Failed to list VMs: $_"
}

# Resource groups
try {
    $resourceGroups = Get-AzResourceGroup
    Write-Output "$($resourceGroups.Count) resource group(s):"
    foreach ($rg in $resourceGroups) {
        $count = (Get-AzResource -ResourceGroupName $rg.ResourceGroupName).Count
        Write-Output "  $($rg.ResourceGroupName) ($($rg.Location)) - $count resources"
    }
    Write-Output ""
} catch {
    Write-Error "Failed to list RGs: $_"
}

# Environment
Write-Output "Environment:"
Write-Output "  COMPUTERNAME: $env:COMPUTERNAME"
Write-Output "  USERNAME: $env:USERNAME"
Write-Output "  OS: $env:OS"

if ($env:AUTOMATION_HYBRID_WORKER -eq "True" -or $PSPrivateMetadata.JobId) {
    Write-Output "  Running on hybrid worker (Job: $($PSPrivateMetadata.JobId))"
} else {
    Write-Output "  Running in Azure sandbox"
}

Write-Output ""
Write-Output "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"
