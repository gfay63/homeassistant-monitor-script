# Define variables
$homeAssistantUrl = "http://homeassistant.local:8123/"
$vmName = "Home Assistant"  # Change to your VM's name
$checkInterval = 5  # Interval in minutes
$logFile = "C:\scripts\HomeAssistantRestart.log"  # Path to your log file
$notificationUrl = "http://homeassistant.local:8123/api/webhook/notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B"  # URL for notification

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
        Invoke-WebRequest -Uri $notificationUrl -Method Post
        Log-Message "Notification sent to $notificationUrl"
    } catch {
        Log-Message "Failed to send notification to $notificationUrl"
    }
}

# Log script launch
Log-Message "Home Assistant monitoring script started."

while ($true) {
    if (-not (Check-HomeAssistant)) {
        Log-Message "Home Assistant is unresponsive. Restarting the VM."
        Restart-VirtualBoxVM
    } else {
        Log-Message "Home Assistant is responsive."
    }
    Start-Sleep -Seconds ($checkInterval * 60)
}
