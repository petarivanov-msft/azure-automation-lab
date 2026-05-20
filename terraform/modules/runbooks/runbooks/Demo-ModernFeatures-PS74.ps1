<#
.SYNOPSIS
    PS 7.4 modern language features demo

.NOTES
    Requires: Az module 12.3.0+
    Runtime: PowerShell 7.4
#>

try {
    Write-Output "Demo-ModernFeatures-PS74"
    Write-Output "PowerShell $($PSVersionTable.PSVersion)"
    Write-Output ""

    Connect-AzAccount -Identity | Out-Null

    $vms = Get-AzVM -Status
    $vmCount = $vms.Count

    # Ternary operator (PS 7+)
    Write-Output "Ternary operator:"
    $vmStatus = $vmCount -gt 0 ? "$vmCount VM(s) found" : "No VMs in subscription"
    Write-Output "  $vmStatus"
    foreach ($vm in $vms | Select-Object -First 3) {
        $stateText = $vm.PowerState -eq "VM running" ? "Running" : "Stopped"
        Write-Output "  $($vm.Name): $stateText"
    }
    Write-Output ""

    # Null-coalescing (PS 7+)
    Write-Output "Null-coalescing operator (??):"
    foreach ($vm in $vms | Select-Object -First 3) {
        $environment = $vm.Tags['Environment'] ?? 'Not Tagged'
        $owner       = $vm.Tags['Owner']       ?? 'Unknown'
        Write-Output "  $($vm.Name) - Environment: $environment, Owner: $owner"
    }
    Write-Output ""

    # Null-conditional assignment (??=)
    Write-Output "Null-conditional assignment (??=):"
    $config = @{ MaxRetries = $null; Timeout = 30 }
    $config.MaxRetries ??= 3
    $config.Timeout    ??= 60   # won't change, already 30
    $config.LogLevel   ??= "Info"
    Write-Output "  MaxRetries: $($config.MaxRetries) | Timeout: $($config.Timeout) | LogLevel: $($config.LogLevel)"
    Write-Output ""

    # Enhanced switch
    Write-Output "Switch with expressions:"
    $resourceGroups = Get-AzResourceGroup
    foreach ($rg in $resourceGroups | Select-Object -First 3) {
        $count = (Get-AzResource -ResourceGroupName $rg.ResourceGroupName).Count
        $size  = switch ($count) {
            { $_ -eq 0 }  { "Empty" }
            { $_ -le 5 }  { "Small" }
            { $_ -le 15 } { "Medium" }
            { $_ -le 30 } { "Large" }
            default        { "Extra Large" }
        }
        Write-Output "  $($rg.ResourceGroupName): $count resources ($size)"
    }
}
catch {
    Write-Error "Error: $_"
    throw $_
}
