# Define variables
$homeAssistantUrl = "http://homeassistant.local:8123/"
$vmName = "Home Assistant"  # Change to your VM's name
$checkInterval = 5  # Interval in minutes
$logFile = "C:\scripts\HomeAssistantRestart.log"  # Path to your log file
$webhookUrl = "http://homeassistant.local:8123/api/webhook/notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B"  # URL for notification

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
        code = $code
        message = $message
        timestamp = $timestamp
        errorInfo = $errorInfo
    } | ConvertTo-Json

    try {
        Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $jsonPayload -ContentType "application/json"
        Log-Message "Notification sent: $code - $message"
    } catch {
        Log-Message "Failed to send notification: $code - $message"
    }
}

function Check-HomeAssistant {
    try {
        $response = Invoke-WebRequest -Uri $homeAssistantUrl -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            return $true
        }
    } catch {
        return $false
    }
}

function Restart-VirtualBoxVM {
    Log-Message "Attempting to restart VirtualBox VM: $vmName"
    $stopAttempts = 0
    $stopped = $false

    while (-not $stopped -and $stopAttempts -lt $maxStopAttempts) {
        try {
            & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm $vmName poweroff
            Start-Sleep -Seconds 10
            $vmStatus = & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" showvminfo $vmName --machinereadable | Select-String -Pattern '^VMState="poweroff"$'

            if ($vmStatus) {
                $stopped = $true
            } else {
                $stopAttempts++
                Log-Message "Failed to stop VM. Attempt $stopAttempts of $maxStopAttempts."
                Start-Sleep -Seconds ($stopRetryInterval * 60)
            }
        } catch {
            $stopAttempts++
            Log-Message "Error stopping VM: $_. Attempt $stopAttempts of $maxStopAttempts."
            Start-Sleep -Seconds ($stopRetryInterval * 60)
        }
    }

    if ($stopped) {
        try {
            & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm $vmName --type headless
            $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Log-Message "Successfully restarted VirtualBox VM: $vmName"
            Send-Notification -code "harestart" -message "Home Assistant restarted"
        } catch {
            $errorMessage = "Error starting VM: $_"
            Log-Message $errorMessage
            $errorCount++
            $lastError = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $lastErrorMessage = $_.Exception.Message
            Send-Notification -code "error" -message "HA Script Error - $errorMessage" -errorInfo $errorMessage
        }
    } else {
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

Press Ctrl+C to exit...
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
        } else {
            Log-Message "Home Assistant is responsive."
        }
    } catch {
        $errorMessage = "Error checking Home Assistant: $_"
        Log-Message $errorMessage
        $errorCount++
        $lastError = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $lastErrorMessage = $_.Exception.Message
        Send-Notification -code "error" -message "HA Script Error - $errorMessage" -errorInfo $errorMessage
    }

    Update-Display
    Start-Sleep -Seconds ($checkInterval * 60)
}
