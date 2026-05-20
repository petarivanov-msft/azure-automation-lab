<#
.SYNOPSIS
    Get Azure subscription and resource info - PS 5.1

.NOTES
    Requires: Az.Accounts, Az.Resources
    Runtime: PowerShell 5.1
#>

try {
    Write-Output "Get-AzureInfo-PS51"
    Write-Output "PowerShell $($PSVersionTable.PSVersion)"
    Write-Output ""

    $AzureContext = (Connect-AzAccount -Identity).Context
    if (-not $AzureContext) { throw "Managed Identity auth failed" }
    Write-Output "Authenticated as: $($AzureContext.Account.Id)"
    Write-Output ""

    $subscription = Get-AzSubscription -SubscriptionId $AzureContext.Subscription.Id
    Write-Output "Subscription : $($subscription.Name)"
    Write-Output "ID           : $($subscription.Id)"
    Write-Output "Tenant       : $($subscription.TenantId)"
    Write-Output "State        : $($subscription.State)"
    Write-Output ""

    $resources = Get-AzResource
    $resourcesByType = $resources | Group-Object -Property Type | Sort-Object -Property Count -Descending

    Write-Output "Resource count by type:"
    foreach ($type in $resourcesByType) {
        Write-Output "$($type.Count.ToString().PadLeft(5)) | $($type.Name)"
    }
    Write-Output ""
    Write-Output "Total: $($resources.Count)"
    Write-Output ""

    Write-Output "Resource groups:"
    $resourceGroups = Get-AzResourceGroup | Sort-Object ResourceGroupName
    foreach ($rg in $resourceGroups) {
        $count = ($resources | Where-Object { $_.ResourceGroupName -eq $rg.ResourceGroupName }).Count
        Write-Output "  $($rg.ResourceGroupName) - $($rg.Location) ($count resources)"
    }
}
catch {
    Write-Error "Error: $_"
    throw $_
}
