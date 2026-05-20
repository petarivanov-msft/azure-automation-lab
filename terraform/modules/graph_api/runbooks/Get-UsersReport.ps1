<#
.SYNOPSIS
    Get users from Microsoft Graph

.NOTES
    Requires: User.Read.All permission on managed identity
#>

param(
    [int]$TopCount = 10
)

try {
    Connect-MgGraph -Identity -NoWelcome
    Write-Output "Connected: $(Get-MgContext | Select-Object -ExpandProperty Account)"
    Write-Output ""

    $users = Get-MgUser -Top $TopCount -Property DisplayName,UserPrincipalName,Mail,AccountEnabled,CreatedDateTime,UserType -Sort DisplayName
    Write-Output "$($users.Count) users:"

    foreach ($user in $users) {
        Write-Output "  $($user.DisplayName) | $($user.UserPrincipalName) | Enabled: $($user.AccountEnabled) | Type: $($user.UserType)"
    }
} catch {
    Write-Error "Error: $_"
    throw
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
