# Define variables
$homeAssistantUrl = "http://homeassistant.local:8123/"
$vmName = "Home Assistant"  # Change to your VM's name
$checkInterval = 5  # Interval in minutes
$logFile = "C:\scripts\HomeAssistantRestart.log"  # Path to your log file
$webhookUrl = "http://homeassistant.local:8123/api/webhook/notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B"  # URL for notification
$startType = "gui"  # Change to "headless" for headless start
$accessToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiZmFlMjhlZjZhMzg0NTYzYjE0MDE0OTg1Yjk5Y2FjNiIsImlhdCI6MTcxNjc2MTM3MywiZXhwIjoyMDMyMTIxMzczfQ.fMH4t1ihSeihVNbTxKDLJxD9suRoIqtZyLIwfuhJtdQ"  # Replace with your long-lived access token

$checkCount = 0
$restartCount = 0
$errorCount = 0
$scriptStart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lastUpdate = $null
$lastRestart = $null
$lastError = $null
$lastErrorMessage = $null
$maxStopAttempts = 5
$stopRetryInterval = 1  # in minutes

function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Output $logEntry
}

function Send-Notification {
    param (
        [string]$code,
        [string]$message,
        [string]$errorInfo = $null
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $jsonPayload = @{
        code      = $code
        message   = $message
        timestamp = $timestamp
        errorInfo = $errorInfo
    } | ConvertTo-Json

    $notificationSent = $false
    while (-not $notificationSent) {
        try {
            $response = Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $jsonPayload -ContentType "application/json"
            if ($response.StatusCode -eq 200) {
                Log-Message "Notification sent: $code - $message"
                $notificationSent = $true
            }
        }
        catch {
            Log-Message "Failed to send notification: $code - $message. Retrying in 10 seconds..."
            Start-Sleep -Seconds 10
        }
    }
}

function Check-HomeAssistant {
    try {
        $response = Invoke-WebRequest -Uri "${homeAssistantUrl}api/config" -TimeoutSec 10 -Headers @{
            Authorization = "Bearer $accessToken"
        }
        if ($response.StatusCode -eq 200) {
            return $true
        }
    }
    catch {
        return $false
    }
}

function Restart-VirtualBoxVM {
    Log-Message "Attempting to restart VirtualBox VM: $vmName"
    $stopAttempts = 0
    $stopped = $false

    while (-not $stopped -and $stopAttempts -lt $maxStopAttempts) {
        try {
            & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm $vmName acpipowerbutton
            Start-Sleep -Seconds 30  # Give the VM some time to shut down gracefully
            $vmStatus = & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" showvminfo $vmName --machinereadable | Select-String -Pattern '^VMState="poweroff"$'

            if ($vmStatus) {
                $stopped = $true
            }
            else {
                $stopAttempts++
                Log-Message "Failed to stop VM. Attempt $stopAttempts of $maxStopAttempts."
                Start-Sleep -Seconds ($stopRetryInterval * 60)
            }
        }
        catch {
            $stopAttempts++
            Log-Message "Error stopping VM: $_. Attempt $stopAttempts of $maxStopAttempts."
            Start-Sleep -Seconds ($stopRetryInterval * 60)
        }
    }

    if ($stopped) {
        try {
            & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm $vmName --type $startType
            $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Log-Message "Successfully restarted VirtualBox VM: $vmName"

            # Wait until Home Assistant is fully operational
            $haResponsive = $false
            while (-not $haResponsive) {
                if (Check-HomeAssistant) {
                    $haResponsive = $true
                }
                else {
                    Start-Sleep -Seconds 10
                }
            }

            Send-Notification -code "harestart" -message "Home Assistant restarted"
        }
        catch {
            $errorMessage = "Error starting VM: $_"
            Log-Message $errorMessage
            $errorCount++
            $lastError = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $lastErrorMessage = $_.Exception.Message
            Send-Notification -code "error" -message "HA Script Error - $errorMessage" -errorInfo $errorMessage
        }
    }
    else {
        $errorMessage = "Failed to stop VM after $maxStopAttempts attempts."
        Log-Message $errorMessage
        $errorCount++
        $lastError = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $lastErrorMessage = $errorMessage
        Send-Notification -code "error" -message "HA Script Error - $errorMessage" -errorInfo $errorMessage
    }
}

function Update-Display {
    $consoleOutput = @"
Script Start: $scriptStart
Checks: $checkCount
Restarts: $restartCount
Errors: $errorCount
Last Update: $lastUpdate
Last Restart: $lastRestart
Last Error: $lastError - $lastErrorMessage

Press 'R' to force a restart. Press Ctrl+C to exit...
"@
    Clear-Host
    Write-Output $consoleOutput
}

# Log script launch
Log-Message "Home Assistant monitoring script started."
Send-Notification -code "launched" -message "Script launched"

while ($true) {
    $checkCount++
    $lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        if (-not (Check-HomeAssistant)) {
            $restartCount++
            Log-Message "Home Assistant is unresponsive. Restarting the VM."
            Restart-VirtualBoxVM
        }
        else {
            Log-Message "Home Assistant is responsive."
        }
    }
    catch {
        $errorMessage = "Error checking Home Assistant: $_"
        Log-Message $errorMessage
        $errorCount++
        $lastError = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $lastErrorMessage = $_.Exception.Message
        Send-Notification -code "error" -message "HA Script Error - $errorMessage" -errorInfo $errorMessage
    }

    Update-Display

    $endTime = (Get-Date).AddMinutes($checkInterval)

    while ((Get-Date) -lt $endTime) {
        if ([System.Console]::KeyAvailable) {
            $key = [System.Console]::ReadKey($true).Key
            if ($key -eq 'R') {
                $restartCount++
                $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Log-Message "Manual restart triggered."
                Restart-VirtualBoxVM
                Update-Display
            }
        }
        Start-Sleep -Milliseconds 500
    }
}
