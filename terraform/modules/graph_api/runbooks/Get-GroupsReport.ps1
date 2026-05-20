<#
.SYNOPSIS
    Get groups from Microsoft Graph

.NOTES
    Requires: Group.Read.All permission on managed identity
#>

param(
    [int]$TopCount = 10,
    [string]$GroupType = "All"  # All, Security, Microsoft365
)

try {
    Connect-MgGraph -Identity -NoWelcome
    Write-Output "Connected | TopCount=$TopCount | GroupType=$GroupType"
    Write-Output ""

    $groups = Get-MgGroup -Top $TopCount -Property DisplayName,Description,GroupTypes,CreatedDateTime,SecurityEnabled,MailEnabled -Sort DisplayName

    if ($GroupType -eq "Security") {
        $groups = $groups | Where-Object { $_.SecurityEnabled -eq $true -and $_.MailEnabled -eq $false }
    } elseif ($GroupType -eq "Microsoft365") {
        $groups = $groups | Where-Object { $_.GroupTypes -contains "Unified" }
    }

    Write-Output "$($groups.Count) group(s):"
    foreach ($group in $groups) {
        $type = if ($group.GroupTypes -contains "Unified") { "M365" }
                elseif ($group.SecurityEnabled) { "Security" }
                else { "Distribution" }
        Write-Output "  $($group.DisplayName) | $type | Mail: $($group.MailEnabled) | Created: $($group.CreatedDateTime)"
        if ($group.Description) { Write-Output "    $($group.Description)" }
    }
} catch {
    Write-Error "Error: $_"
    throw
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
