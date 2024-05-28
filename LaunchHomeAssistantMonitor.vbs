Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoExit -ExecutionPolicy Bypass -File ""C:\scripts\home-assistant-monitor\RestartHomeAssistant.ps1""", 1, false
