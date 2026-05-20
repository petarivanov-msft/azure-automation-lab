<#
.SYNOPSIS
    Azure resource report - PS 7.4

.NOTES
    Requires: Az module 12.3.0+
    Runtime: PowerShell 7.4
#>

try {
    $reportStart = Get-Date
    Write-Output "Get-ResourceReport-PS74"
    Write-Output "PowerShell $($PSVersionTable.PSVersion) | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"
    Write-Output ""

    Connect-AzAccount -Identity | Out-Null

    $context = Get-AzContext
    Write-Output "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    Write-Output ""

    $allResources   = Get-AzResource
    $resourceGroups = Get-AzResourceGroup
    $vms            = Get-AzVM -Status

    Write-Output "$($allResources.Count) resources | $($resourceGroups.Count) RGs | $($vms.Count) VMs"
    Write-Output ""

    # By type
    Write-Output "Resources by type (top 15):"
    $byType   = $allResources | Group-Object -Property Type | Sort-Object Count -Descending
    $maxCount = ($byType | Measure-Object -Property Count -Maximum).Maximum
    foreach ($type in $byType | Select-Object -First 15) {
        $pct  = [math]::Round(($type.Count / $allResources.Count) * 100, 1)
        $bar  = "█" * [math]::Round(($type.Count / $maxCount) * 25)
        $name = (($type.Name -split '/')[-1]).PadRight(25)
        Write-Output "  $name $bar $($type.Count.ToString().PadLeft(4)) ($pct%)"
    }
    Write-Output ""

    # By location
    Write-Output "Resources by location:"
    $byLocation = $allResources | Group-Object -Property Location | Sort-Object Count -Descending
    foreach ($loc in $byLocation) {
        $pct  = [math]::Round(($loc.Count / $allResources.Count) * 100, 1)
        $name = $loc.Name.PadRight(20)
        Write-Output "  $name $($loc.Count.ToString().PadLeft(4)) ($pct%)"
    }
    Write-Output ""

    # VM power states
    if ($vms.Count -gt 0) {
        Write-Output "VM power states:"
        $vms | Group-Object PowerState | Sort-Object Count -Descending | ForEach-Object {
            Write-Output "  $($_.Name): $($_.Count)"
        }
        Write-Output ""
    }

    # Tag compliance
    Write-Output "Tag compliance:"
    $requiredTags = @('Environment', 'Owner', 'CostCenter')
    $tagPcts = foreach ($tag in $requiredTags) {
        $tagged = ($allResources | Where-Object { $_.Tags[$tag] }).Count
        $pct    = $allResources.Count -gt 0 ? [math]::Round(($tagged / $allResources.Count) * 100, 1) : 0
        $icon   = $pct -ge 80 ? "OK" : ($pct -ge 50 ? "warn" : "FAIL")
        Write-Output "  [$icon] $($tag.PadRight(15)): $tagged/$($allResources.Count) ($pct%)"
        $pct
    }
    $overall = [math]::Round(($tagPcts | Measure-Object -Average).Average, 1)
    Write-Output "  Overall: $overall%"
    Write-Output ""

    # Resource groups (parallel)
    Write-Output "Resource groups:"
    $rgAnalysis = $resourceGroups | ForEach-Object -Parallel {
        $rgResources = Get-AzResource -ResourceGroupName $_.ResourceGroupName
        [PSCustomObject]@{
            Name          = $_.ResourceGroupName
            Location      = $_.Location
            ResourceCount = $rgResources.Count
            Types         = ($rgResources | Group-Object Type).Count
        }
    } -ThrottleLimit 5 | Sort-Object ResourceCount -Descending

    foreach ($rg in $rgAnalysis) {
        Write-Output "  $($rg.Name.PadRight(35)) $($rg.ResourceCount.ToString().PadLeft(3)) resources | $($rg.Types) types"
    }
    Write-Output ""

    $duration = [math]::Round(((Get-Date) - $reportStart).TotalSeconds, 2)
    Write-Output "Completed in ${duration}s"
}
catch {
    Write-Error "Error: $_"
    throw $_
}
