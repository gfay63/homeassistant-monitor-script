# Define variables
$homeAssistantUrl = "http://homeassistant.local:8123/"
$vmName = "Home Assistant"  # Change to your VM's name
$checkInterval = 5  # Interval in minutes
$logFile = "C:\scripts\home-assistant-monitor\HomeAssistantRestart.log"  # Path to your log file
$accessTokenFile = "C:\scripts\home-assistant-monitor\accessToken.txt"  # Path to your access token file
$webhookUrl = "http://homeassistant.local:8123/api/webhook/notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B"  # URL for notification
$startType = "gui"  # Change to "headless" for headless start
$vboxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"  # Path to VBoxManage

# Read access token from file
$accessToken = Get-Content -Path $accessTokenFile -Raw

$checkCount = 0
$restartCount = 0
$errorCount = 0
$consecutiveFailures = 0
$scriptStart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lastUpdate = $null
$lastRestart = $null
$lastError = $null
$lastErrorMessage = $null
$maxStopAttempts = 5
$stopRetryInterval = 1  # in minutes
$maxConsecutiveFailures = 3  # Number of consecutive failures before restarting VM

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

    try {
        $response = Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $jsonPayload -ContentType "application/json"
        if ($response.StatusCode -eq 200) {
            Log-Message "Notification sent: $code - $message"
        }
        else {
            Log-Message "Failed to send notification: $code - $message"
        }
    }
    catch {
        Log-Message "Error sending notification: $code - $message. Error: $_"
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

function Check-VMRunning {
    try {
        $vmStatus = & "$vboxManagePath" showvminfo $vmName --machinereadable | Select-String -Pattern '^VMState="running"$'
        if ($vmStatus) {
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
            & "$vboxManagePath" controlvm $vmName acpipowerbutton
            Start-Sleep -Seconds 30  # Give the VM some time to shut down gracefully
            $vmStatus = & "$vboxManagePath" showvminfo $vmName --machinereadable | Select-String -Pattern '^VMState="poweroff"$'

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
            & "$vboxManagePath" startvm $vmName --type $startType
            $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Log-Message "Successfully restarted VirtualBox VM: $vmName"

            # Wait until Home Assistant is fully operational
            $haResponsive = $false
            $restartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            while (-not $haResponsive) {
                if (Check-HomeAssistant) {
                    $haResponsive = $true
                }
                else {
                    Start-Sleep -Seconds 10
                }
            }

            Log-Message "Home Assistant became responsive at $restartTime"
            Start-Sleep -Seconds 300  # Wait 5 minutes before sending the notification
            Send-Notification -code "harestart" -message "Home Assistant restarted at $restartTime"
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

function Shutdown-VirtualBoxVM {
    Log-Message "Shutting down VirtualBox VM: $vmName"
    try {
        & "$vboxManagePath" controlvm $vmName acpipowerbutton
        Log-Message "VM $vmName shutdown initiated."
        Send-Notification -code "shutdown" -message "Home Assistant VM is shutting down"
    }
    catch {
        $errorMessage = "Error shutting down VM: $_"
        Log-Message $errorMessage
        $errorCount++
        $lastError = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $lastErrorMessage = $_.Exception.Message
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

Press 'R' to force a restart. Press 'S' to shutdown. Press Ctrl+C to exit...
"@
    Clear-Host
    Write-Output $consoleOutput
}

# Log script launch
Log-Message "Home Assistant monitoring script started."
Send-Notification -code "launched" -message "Script launched"

# Initial check for Home Assistant responsiveness
$haResponsive = Check-HomeAssistant

if ($haResponsive) {
    Log-Message "Home Assistant is responsive at startup."
}
else {
    Log-Message "Home Assistant is not responsive at startup."
    $vmRunning = Check-VMRunning

    if ($vmRunning) {
        Log-Message "VM is running. Checking HA responsiveness every minute for up to 5 minutes."
        $maxWaitTime = 5
        $waitedTime = 0

        while ($waitedTime -lt $maxWaitTime -and -not $haResponsive) {
            Start-Sleep -Seconds 60
            $waitedTime++
            $haResponsive = Check-HomeAssistant
            if ($haResponsive) {
                Log-Message "Home Assistant became responsive after $waitedTime minutes."
            }
        }
    }

    if (-not $haResponsive) {
        Log-Message "Home Assistant did not become responsive after waiting. Restarting the VM."
        Restart-VirtualBoxVM
    }
}

Update-Display

while ($true) {
    $checkCount++
    $lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        if (-not (Check-HomeAssistant)) {
            $consecutiveFailures++
            Log-Message "Home Assistant is unresponsive. Consecutive failures: $consecutiveFailures."

            if ($consecutiveFailures -ge $maxConsecutiveFailures) {
                $restartCount++
                Log-Message "Home Assistant is unresponsive for $consecutiveFailures consecutive checks. Restarting the VM."
                Restart-VirtualBoxVM
                $consecutiveFailures = 0  # Reset consecutive failures after a restart
            }
        }
        else {
            Log-Message "Home Assistant is responsive."
            $consecutiveFailures = 0  # Reset consecutive failures on successful check
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
            elseif ($key -eq 'S') {
                Log-Message "Manual shutdown triggered."
                Shutdown-VirtualBoxVM
                Update-Display
            }
        }
        Start-Sleep -Milliseconds 500
    }
}
