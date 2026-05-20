<#
.SYNOPSIS
    ForEach-Object -Parallel demo with sequential comparison

.NOTES
    Requires: Az module 12.3.0+
    Runtime: PowerShell 7.4
#>

try {
    Write-Output "Demo-ParallelProcessing-PS74"
    Write-Output "PowerShell $($PSVersionTable.PSVersion)"
    Write-Output ""

    Connect-AzAccount -Identity | Out-Null

    $resourceGroups = Get-AzResourceGroup
    Write-Output "Resource groups: $($resourceGroups.Count)"
    Write-Output ""

    # Sequential
    $seqStart = Get-Date
    $seqResults = foreach ($rg in $resourceGroups) {
        $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
        [PSCustomObject]@{
            ResourceGroup = $rg.ResourceGroupName
            Location      = $rg.Location
            ResourceCount = $resources.Count
        }
    }
    $seqDuration = ((Get-Date) - $seqStart).TotalSeconds
    Write-Output "Sequential: $([math]::Round($seqDuration, 2))s"

    # Parallel (PS 7.4)
    $parStart = Get-Date
    $parResults = $resourceGroups | ForEach-Object -Parallel {
        Connect-AzAccount -Identity | Out-Null
        $resources = Get-AzResource -ResourceGroupName $_.ResourceGroupName
        [PSCustomObject]@{
            ResourceGroup = $_.ResourceGroupName
            Location      = $_.Location
            ResourceCount = $resources.Count
        }
    } -ThrottleLimit 5
    $parDuration = ((Get-Date) - $parStart).TotalSeconds
    Write-Output "Parallel:   $([math]::Round($parDuration, 2))s"

    $improvement = $seqDuration -gt 0 ? [math]::Round((($seqDuration - $parDuration) / $seqDuration) * 100, 1) : 0
    Write-Output "Speedup:    $improvement%"
    Write-Output ""

    Write-Output "Results:"
    foreach ($result in $parResults | Sort-Object ResourceCount -Descending) {
        Write-Output "$($result.ResourceCount.ToString().PadLeft(4)) | $($result.ResourceGroup) ($($result.Location))"
    }

    $total = ($parResults | Measure-Object -Property ResourceCount -Sum).Sum
    Write-Output ""
    Write-Output "Total resources: $total"
}
catch {
    Write-Error "Error: $_"
    throw $_
}
