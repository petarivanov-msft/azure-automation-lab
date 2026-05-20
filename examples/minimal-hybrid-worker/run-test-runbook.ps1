param(
    [string]$ResourceGroupName = "rg-hybrid-worker-lab",
    [string]$AutomationAccountName = "hwlab-automation",
    [string]$RunbookName = "Test-HybridWorker-ManagedIdentity",
    [string]$HybridWorkerGroup = "hwlab-worker-group"
)

Write-Host "Starting $RunbookName on $HybridWorkerGroup..." -ForegroundColor Cyan

$job = az automation runbook start `
    --automation-account-name $AutomationAccountName `
    --resource-group $ResourceGroupName `
    --name $RunbookName `
    --run-on $HybridWorkerGroup | ConvertFrom-Json

$jobName = $job.name
Write-Host "Job started: $jobName" -ForegroundColor Yellow
Write-Host "Waiting for completion..."

$maxWait = 120
$waited = 0
$status = "Running"

while ($status -notin @("Completed", "Failed", "Stopped", "Suspended") -and $waited -lt $maxWait) {
    Start-Sleep -Seconds 5
    $waited += 5
    
    $jobStatus = az automation job show `
        --automation-account-name $AutomationAccountName `
        --resource-group $ResourceGroupName `
        --name $jobName | ConvertFrom-Json
    
    $status = $jobStatus.status
    Write-Host "." -NoNewline
}

Write-Host ""
Write-Host "Job Status: $status" -ForegroundColor $(if ($status -eq "Completed") { "Green" } else { "Red" })

if ($status -eq "Completed") {
    $subscriptionId = (az account show --query id -o tsv)
    $outputUrl = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName/jobs/$jobName/output?api-version=2023-11-01"
    
    Write-Host "`n========== JOB OUTPUT ==========" -ForegroundColor Green
    az rest --method get --url $outputUrl
    Write-Host "========== END OUTPUT ==========" -ForegroundColor Green
    
    Write-Host "`nPortal: https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName/jobs/$jobName" -ForegroundColor Cyan
} else {
    Write-Host "Job did not complete. Check the portal for details." -ForegroundColor Red
}
