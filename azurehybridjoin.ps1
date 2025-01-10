# ------------------------------------------
# Azure Hybrid Join Script
# Forces the Workplace Join scheduled task and verifies Azure AD Hybrid Join status.
# Retries up to the maximum allowed attempts if the join is not successful.
# ------------------------------------------
# Run this script as an administrator

$MaxRetries = 10
$RetryInterval = 120 # in seconds

function Force-HybridJoin {
    try {
        Write-Output "Starting Workplace Join scheduled task..."
        Start-ScheduledTask -TaskName "Automatic-Device-Join" -TaskPath "\Microsoft\Windows\Workplace Join"
        Write-Output "Workplace Join task started successfully. Waiting for $RetryInterval seconds..."
        Start-Sleep -Seconds $RetryInterval
    } catch {
        Write-Output "Error: Failed to start the scheduled task. $_"
        throw
    }
}

function Check-JoinStatus {
    Write-Output "Checking Hybrid Azure AD Join status..."
    try {
        $AzureStatus = dsregcmd /status
        $azureAdJoinedLine = $AzureStatus | Select-String -Pattern "AzureAdJoined"
        if ($azureAdJoinedLine -match "AzureAdJoined\s*:\s*(\w+)") {
            return $matches[1].ToUpper() -eq 'YES'
        } else {
            return $false
        }
    } catch {
        Write-Output "Error: Failed to check join status. $_"
        throw
    }
}

$RetryCount = 0
$Joined = $false

Write-Output "Initiating Hybrid Azure AD Join process..."

while (-not $Joined -and $RetryCount -lt $MaxRetries) {
    try {
        Force-HybridJoin
        $Joined = Check-JoinStatus
    } catch {
        Write-Output "An error occurred during Hybrid Join attempt $RetryCount. $_" -ForegroundColor Red
    }

    if (-not $Joined) {
        Write-Output "Hybrid Join attempt $RetryCount failed. Retrying in $RetryInterval seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds $RetryInterval
    }

    $RetryCount++
}

if ($Joined) {
    Write-Output "Success: This device has Hybrid Joined Azure AD." -ForegroundColor Green
    Exit 0
} else {
    Write-Output "Error: Failed to join the device to Azure AD after $MaxRetries attempts." -ForegroundColor Red
    Exit 1
}
exit
