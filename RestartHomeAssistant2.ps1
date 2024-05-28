# Define variables
$homeAssistantUrl = "http://homeassistant.local:8123/"
$vmName = "Home Assistant"  # Change to your VM's name
$checkInterval = 5  # Interval in minutes
$logFile = "C:\scripts\HomeAssistantRestart.log"  # Path to your log file
$webhookUrl= "http://homeassistant.local:8123/api/webhook/notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B"  # URL for notification

$checkCount = 0
$restartCount = 0
$lastUpdate = $null
$lastRestart = $null

function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Output $logEntry
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
    Log-Message "Restarting VirtualBox VM: $vmName"
    & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm $vmName poweroff
    Start-Sleep -Seconds 10
    & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm $vmName --type headless

    # Send notification
    try {
        $null = Invoke-WebRequest -Uri $webhookUrl -Method Post
        Log-Message "Notification sent to $webhookUrl"
    } catch {
        Log-Message "Failed to send notification to $webhookUrl"
    }
}

function Update-Display {
    $consoleOutput = @"
Checks: $checkCount
Restarts: $restartCount
Last Update: $lastUpdate
Last Restart: $lastRestart

Press Ctrl+C to exit...
"@
    Clear-Host
    Write-Output $consoleOutput
}

# Log script launch
Log-Message "Home Assistant monitoring script started."

while ($true) {
    $checkCount++
    $lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if (-not (Check-HomeAssistant)) {
        $restartCount++
        $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Log-Message "Home Assistant is unresponsive. Restarting the VM."
        Restart-VirtualBoxVM
    } else {
        Log-Message "Home Assistant is responsive."
    }

    Update-Display
    Start-Sleep -Seconds ($checkInterval * 60)
}$webhookUrl = "http://<your_home_assistant_ip>:8123/api/webhook/<webhook_id>"  # Webhook URL

$checkCount = 0
$restartCount = 0
$lastUpdate = $null
$lastRestart = $null

function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Output $logEntry
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
    Log-Message "Restarting VirtualBox VM: $vmName"
    & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm $vmName poweroff
    Start-Sleep -Seconds 10
    & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm $vmName --type headless

    # Send notification
    try {
        $null = Invoke-WebRequest -Uri $webhookUrl -Method Post
        Log-Message "Notification sent to $webhookUrl"
    } catch {
        Log-Message "Failed to send notification to $webhookUrl"
    }
}

function Update-Display {
    $consoleOutput = @"
Checks: $checkCount
Restarts: $restartCount
Last Update: $lastUpdate
Last Restart: $lastRestart

Press Ctrl+C to exit...
"@
    Clear-Host
    Write-Output $consoleOutput
}

# Log script launch
Log-Message "Home Assistant monitoring script started."

while ($true) {
    $checkCount++
    $lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if (-not (Check-HomeAssistant)) {
        $restartCount++
        $lastRestart = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Log-Message "Home Assistant is unresponsive. Restarting the VM."
        Restart-VirtualBoxVM
    } else {
        Log-Message "Home Assistant is responsive."
    }

    Update-Display
    Start-Sleep -Seconds ($checkInterval * 60)
}