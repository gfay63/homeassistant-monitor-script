# Home Assistant Monitoring Script

This PowerShell script monitors the status of a Home Assistant instance running in a VirtualBox VM. If Home Assistant becomes unresponsive, the script will attempt to restart the VM to restore functionality. It also includes manual restart and shutdown capabilities.

## Features

- Monitors Home Assistant responsiveness.
- Automatically restarts the VirtualBox VM if Home Assistant is unresponsive.
- Provides manual commands to restart or shut down the VM.
- Logs all actions and events.
- Sends notifications via a webhook after Home Assistant restarts.

## Requirements

- Windows operating system.
- PowerShell.
- VirtualBox installed.
- Home Assistant running in a VirtualBox VM.
- Long-lived access token for Home Assistant API.
- Webhook URL for notifications.

## Installation

1. **Download the Script**:
    - Save the `RestartHomeAssistant.ps1` script to a directory, e.g., `C:\scripts\home-assistant-monitor\`.

2. **Create Access Token File**:
    - Create a file named `accessToken.txt` in the same directory and store your Home Assistant long-lived access token in it.
    - Example path: `C:\scripts\home-assistant-monitor\accessToken.txt`.

3. **Update Script Configuration**:
    - Open the `RestartHomeAssistant.ps1` script in a text editor and update the following variables as needed:
        ```powershell
        $homeAssistantUrl = "http://homeassistant.local:8123/"
        $vmName = "Home Assistant"
        $checkInterval = 5  # Interval in minutes
        $logFile = "C:\scripts\home-assistant-monitor\HomeAssistantRestart.log"
        $accessTokenFile = "C:\scripts\home-assistant-monitor\accessToken.txt"
        $webhookUrl = "http://homeassistant.local:8123/api/webhook/notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B"
        $startType = "gui"  # Change to "headless" for headless start
        $vboxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"  # Path to VBoxManage
        ```

4. **Set Up Home Assistant Automation**:
    - Add the following automation to your `automations.yaml` file in Home Assistant:
      ```yaml
      alias: "Notification: Home Assistant Events"
      description: Handles various Home Assistant events and sends notifications
      trigger:
        - platform: webhook
          allowed_methods:
            - POST
            - PUT
          local_only: true
          webhook_id: notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B
      condition: []
      action:
        - variables:
            notification_code: "{{ trigger.json.code }}"
            notification_message: "{{ trigger.json.message }}"
            notification_timestamp: "{{ trigger.json.timestamp }}"
            notification_error_info: "{{ trigger.json.errorInfo | default('No additional information') }}"
        - choose:
            - conditions:
                - condition: template
                  value_template: "{{ notification_code == 'launched' }}"
              sequence:
                - service: notify.mobile_app_gfay_iphone13pro
                  data:
                    message: Script launched at {{ notification_timestamp }}
            - conditions:
                - condition: template
                  value_template: "{{ notification_code == 'harestart' }}"
              sequence:
                - service: notify.mobile_app_gfay_iphone13pro
                  data:
                    message: Home Assistant restarted at {{ notification_timestamp }}
            - conditions:
                - condition: template
                  value_template: "{{ notification_code == 'error' }}"
              sequence:
                - service: notify.mobile_app_gfay_iphone13pro
                  data:
                    message: >-
                      Error occurred at {{ notification_timestamp }}: {{
                      notification_message }}
                    data:
                      errorInfo: "{{ notification_error_info }}"
        - condition: template
          value_template: "{{ notification_code not in ['launched', 'harestart', 'error'] }}"
        - service: notify.mobile_app_gfay_iphone13pro
          data:
            message: >-
              Unknown notification code {{ notification_code }} received at {{
              notification_timestamp }}
        - service: rest_command.acknowledge_webhook
          data:
            response: success
      mode: single
      ```

5. **Run the Script**:
    - Open PowerShell as an Administrator.
    - Navigate to the directory containing the script:
        ```shell
        cd C:\scripts\home-assistant-monitor\
        ```
    - Run the script:
        ```shell
        .\RestartHomeAssistant.ps1
        ```

## Usage

- The script will automatically start monitoring Home Assistant.
- It will check the responsiveness of Home Assistant at the interval specified by `$checkInterval`.
- If Home Assistant is unresponsive, the script will attempt to restart the VM.
- Manual Commands:
    - Press `R` to manually restart the VM.
    - Press `S` to manually shut down the VM.
    - Press `Ctrl+C` to exit the script.

## Logging

- All actions and events are logged to the file specified by `$logFile`.
- Example log file path: `C:\scripts\home-assistant-monitor\HomeAssistantRestart.log`.

## Notifications

- Notifications are sent via the webhook URL specified by `$webhookUrl`.
- Notifications include:
    - Script launch.
    - Home Assistant restart.
    - Errors encountered.

## Task Scheduler Setup

To set up the script to run at startup with a visible PowerShell window:

1. **Create a Shortcut to the PowerShell Script**:
    - Navigate to the directory where your `RestartHomeAssistant.ps1` script is located.
    - Right-click in the directory, select `New` > `Shortcut`.
    - In the location field, enter:
      ```shell
      powershell.exe -NoExit -ExecutionPolicy Bypass -File "C:\scripts\home-assistant-monitor\RestartHomeAssistant.ps1"
      ```
    - Click `Next`.
    - Name the shortcut (e.g., `RestartHomeAssistantShortcut`).
    - Click `Finish`.

2. **Alternatively, Create a VBScript File**:
    - Open Notepad and paste the following script:
      ```vbscript
      Set objShell = CreateObject("WScript.Shell")
      objShell.Run "powershell.exe -NoExit -ExecutionPolicy Bypass -File ""C:\scripts\home-assistant-monitor\RestartHomeAssistant.ps1""", 1, false
      ```
    - Save the file as `LaunchHomeAssistantMonitor.vbs` in the same directory as your PowerShell script (e.g., `C:\scripts\home-assistant-monitor\`).

3. **Add the Shortcut or VBScript to the Startup Folder**:
    - Press `Windows + R`, type `shell:startup`, and press `Enter`. This will open the Startup folder.
    - Copy the shortcut (`RestartHomeAssistantShortcut.lnk`) or the VBScript (`LaunchHomeAssistantMonitor.vbs`) to this Startup folder.

4. **Test the Startup Task**:
    - Restart your computer to test if the script runs automatically at startup.
    - The PowerShell window should appear when you log in, running the monitoring script.
## Task Scheduler Setup

To set up the script to run at startup with a visible PowerShell window:

1. **Create a Shortcut to the PowerShell Script**:
    - Navigate to the directory where your `RestartHomeAssistant.ps1` script is located.
    - Right-click in the directory, select `New` > `Shortcut`.
    - In the location field, enter:
      ```shell
      powershell.exe -NoExit -ExecutionPolicy Bypass -File "C:\scripts\home-assistant-monitor\RestartHomeAssistant.ps1"
      ```
    - Click `Next`.
    - Name the shortcut (e.g., `RestartHomeAssistantShortcut`).
    - Click `Finish`.

2. **Alternatively, Create a VBScript File**:
    - Open Notepad and paste the following script:
      ```vbscript
      Set objShell = CreateObject("WScript.Shell")
      objShell.Run "powershell.exe -NoExit -ExecutionPolicy Bypass -File ""C:\scripts\home-assistant-monitor\RestartHomeAssistant.ps1""", 1, false
      ```
    - Save the file as `LaunchHomeAssistantMonitor.vbs` in the same directory as your PowerShell script (e.g., `C:\scripts\home-assistant-monitor\`).

3. **Add the Shortcut or VBScript to the Startup Folder**:
    - Press `Windows + R`, type `shell:startup`, and press `Enter`. This will open the Startup folder.
    - Copy the shortcut (`RestartHomeAssistantShortcut.lnk`) or the VBScript (`LaunchHomeAssistantMonitor.vbs`) to this Startup folder.

4. **Test the Startup Task**:
    - Restart your computer to test if the script runs automatically at startup.
    - The PowerShell window should appear when you log in, running the monitoring script.

## Example

An example log entry might look like this:
```
2024-05-28 05:46:42 - Home Assistant monitoring script started.
2024-05-28 05:46:42 - Notification sent: launched - Script launched
2024-05-28 05:46:42 - Home Assistant is responsive at startup.
2024-05-28 05:51:42 - Home Assistant is responsive.
```

## Troubleshooting

- Ensure the VirtualBox VM name matches the name specified in `$vmName`.
- Ensure the Home Assistant URL and access token are correctly specified.
- Check the log file for detailed error messages if the script is not working as expected.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the need to maintain high availability for Home Assistant instances.
- Uses VirtualBox for VM management and PowerShell for scripting.

---

**Note**: This script is provided as-is without any warranty. Use at your own risk.
