<#
.SYNOPSIS
    VM inventory report - PS 5.1

.NOTES
    Requires: Az.Accounts, Az.Compute
    Runtime: PowerShell 5.1
#>

try {
    $AzureContext = (Connect-AzAccount -Identity).Context
    if (-not $AzureContext) { throw "Managed Identity auth failed" }
    Write-Output "Authenticated - Subscription: $($AzureContext.Subscription.Name)"
    Write-Output ""

    $vms = Get-AzVM -Status

    if ($vms.Count -eq 0) {
        Write-Output "No VMs found."
        return
    }

    Write-Output "Found $($vms.Count) VM(s):"
    Write-Output ""

    foreach ($vm in $vms) {
        Write-Output "Name           : $($vm.Name)"
        Write-Output "Resource Group : $($vm.ResourceGroupName)"
        Write-Output "Location       : $($vm.Location)"
        Write-Output "Size           : $($vm.HardwareProfile.VmSize)"
        Write-Output "OS             : $($vm.StorageProfile.OsDisk.OsType)"
        Write-Output "Power State    : $($vm.PowerState)"
        Write-Output "Provisioning   : $($vm.ProvisioningState)"

        if ($vm.Tags.Count -gt 0) {
            Write-Output "Tags           :"
            foreach ($tag in $vm.Tags.GetEnumerator()) {
                Write-Output "  $($tag.Key): $($tag.Value)"
            }
        }
        Write-Output "---"
    }

    Write-Output ""
    $running   = ($vms | Where-Object { $_.PowerState -eq "VM running" }).Count
    $stopped   = ($vms | Where-Object { $_.PowerState -in "VM deallocated","VM stopped" }).Count
    $windows   = ($vms | Where-Object { $_.StorageProfile.OsDisk.OsType -eq "Windows" }).Count
    $linux     = ($vms | Where-Object { $_.StorageProfile.OsDisk.OsType -eq "Linux" }).Count

    Write-Output "Total: $($vms.Count) | Running: $running | Stopped: $stopped | Windows: $windows | Linux: $linux"
    Write-Output ""

    Write-Output "By size:"
    $vms | Group-Object { $_.HardwareProfile.VmSize } | Sort-Object Count -Descending | ForEach-Object {
        Write-Output "  $($_.Count.ToString().PadLeft(3)) x $($_.Name)"
    }

    Write-Output ""
    Write-Output "By location:"
    $vms | Group-Object Location | Sort-Object Count -Descending | ForEach-Object {
        Write-Output "  $($_.Count.ToString().PadLeft(3)) x $($_.Name)"
    }
}
catch {
    Write-Error "Error: $_"
    throw $_
}
