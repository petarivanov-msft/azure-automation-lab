<#
.SYNOPSIS
    Get app registrations from Microsoft Graph

.NOTES
    Requires: Application.Read.All permission on managed identity
#>

param(
    [int]$TopCount = 10
)

try {
    Connect-MgGraph -Identity -NoWelcome
    Write-Output "Connected | TopCount=$TopCount"
    Write-Output ""

    $apps = Get-MgApplication -Top $TopCount -Property DisplayName,AppId,CreatedDateTime,SignInAudience -Sort DisplayName

    Write-Output "$($apps.Count) application(s):"
    foreach ($app in $apps) {
        Write-Output "  $($app.DisplayName) | AppId: $($app.AppId) | Audience: $($app.SignInAudience) | Created: $($app.CreatedDateTime)"
    }
} catch {
    Write-Error "Error: $_"
    throw
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
