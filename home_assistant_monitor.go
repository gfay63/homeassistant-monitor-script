package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/eiannone/keyboard"
	"github.com/fatih/color"
)

const (
	homeAssistantURL    = "http://homeassistant.local:8123/"
	vmName              = "Home Assistant"
	checkInterval       = 1 * time.Minute
	logFile             = "C:\\scripts\\home-assistant-monitor\\HomeAssistantRestart.log"
	accessTokenFile     = "C:\\scripts\\home-assistant-monitor\\accessToken.txt"
	webhookURL          = "http://homeassistant.local:8123/api/webhook/notification-home-assistant-restarted-3X6GmJIr-ibjHmSPwkwMZU1B"
	startType           = "gui"
	vboxManagePath      = "C:\\Program Files\\Oracle\\VirtualBox\\VBoxManage.exe"
	maxStopAttempts     = 5
	stopRetryInterval   = 1 * time.Minute
	checkResponsiveMax  = 5
	checkResponsiveWait = 1 * time.Minute
)

var (
	checkCount   int
	restartCount int
	errorCount   int
	scriptStart  = time.Now().Format("2006-01-02 15:04:05")
	lastUpdate   string
	lastRestart  string
	lastError    string
	lastErrorMsg string
	dryRun       bool
	debug        bool
)

type NotificationPayload struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	Timestamp string `json:"timestamp"`
	ErrorInfo string `json:"errorInfo,omitempty"`
}

func init() {
	flag.BoolVar(&dryRun, "dry-run", false, "Run in dry-run mode")
	flag.BoolVar(&debug, "debug", false, "Enable debug logging")
	flag.Parse()
}

func logMessage(message string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	logEntry := fmt.Sprintf("%s - %s", timestamp, message)
	file, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open log file: %v", err)
	}
	defer file.Close()
	_, err = file.WriteString(logEntry + "\n")
	if err != nil {
		log.Fatalf("Failed to write to log file: %v", err)
	}
	fmt.Println(logEntry)
}

func sendNotification(code, message, errorInfo string) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	payload := NotificationPayload{
		Code:      code,
		Message:   message,
		Timestamp: timestamp,
		ErrorInfo: errorInfo,
	}
	jsonPayload, err := json.Marshal(payload)
	if err != nil {
		logMessage(fmt.Sprintf("Error marshalling notification payload: %v", err))
		return
	}
	resp, err := http.Post(webhookURL, "application/json", bytes.NewBuffer(jsonPayload))
	if err != nil {
		logMessage(fmt.Sprintf("Error sending notification: %v", err))
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		logMessage(fmt.Sprintf("Notification sent: %s - %s", code, message))
	} else {
		logMessage(fmt.Sprintf("Failed to send notification: %s - %s", code, message))
	}
}

func checkHomeAssistant() bool {
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest("GET", homeAssistantURL+"api/config", nil)
	if err != nil {
		return false
	}
	accessToken, err := os.ReadFile(accessTokenFile)
	if err != nil {
		logMessage(fmt.Sprintf("Error reading access token: %v", err))
		return false
	}
	req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(string(accessToken)))
	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

func checkVMRunning() bool {
	cmd := exec.Command(vboxManagePath, "showvminfo", vmName, "--machinereadable")
	output, err := cmd.Output()
	if err != nil {
		logMessage(fmt.Sprintf("Error checking VM status: %v", err))
		return false
	}
	return strings.Contains(string(output), `VMState="running"`)
}

func shutdownVirtualBoxVM() {
	logMessage(fmt.Sprintf("%sShutting down VirtualBox VM: %s", dryRunPrefix(), vmName))
	if dryRun {
		logMessage("Dry run mode: No actual shutdown will be performed.")
		return
	}
	cmd := exec.Command(vboxManagePath, "controlvm", vmName, "acpipowerbutton")
	if err := cmd.Run(); err != nil {
		logMessage(fmt.Sprintf("Error shutting down VM: %v", err))
	} else {
		logMessage(fmt.Sprintf("%sSuccessfully shut down VirtualBox VM: %s", dryRunPrefix(), vmName))
	}
}

func restartVirtualBoxVM() {
	logMessage(fmt.Sprintf("%sAttempting to restart VirtualBox VM: %s", dryRunPrefix(), vmName))
	if dryRun {
		logMessage("Dry run mode: No actual restart will be performed.")
		return
	}

	stopAttempts := 0
	stopped := false

	for !stopped && stopAttempts < maxStopAttempts {
		cmd := exec.Command(vboxManagePath, "controlvm", vmName, "acpipowerbutton")
		if !dryRun {
			_ = cmd.Run()
		}
		time.Sleep(30 * time.Second)
		cmd = exec.Command(vboxManagePath, "showvminfo", vmName, "--machinereadable")
		output, _ := cmd.Output()
		if strings.Contains(string(output), `VMState="poweroff"`) {
			stopped = true
		} else {
			stopAttempts++
			logMessage(fmt.Sprintf("%sFailed to stop VM. Attempt %d of %d.", dryRunPrefix(), stopAttempts, maxStopAttempts))
			time.Sleep(stopRetryInterval)
		}
	}

	if stopped {
		cmd := exec.Command(vboxManagePath, "startvm", vmName, "--type", startType)
		if !dryRun {
			_ = cmd.Run()
		}
		lastRestart = time.Now().Format("2006-01-02 15:04:05")
		logMessage(fmt.Sprintf("%sSuccessfully restarted VirtualBox VM: %s", dryRunPrefix(), vmName))

		haResponsive := false
		for !haResponsive {
			if checkHomeAssistant() {
				haResponsive = true
			} else {
				time.Sleep(10 * time.Second)
			}
		}
		logMessage(fmt.Sprintf("%sHome Assistant became responsive at %s", dryRunPrefix(), lastRestart))
		time.Sleep(3 * time.Minute)
		sendNotification("harestart", fmt.Sprintf("Home Assistant restarted at %s", lastRestart), "")
	} else {
		errorMessage := fmt.Sprintf("%sFailed to stop VM after %d attempts.", dryRunPrefix(), maxStopAttempts)
		logMessage(errorMessage)
		errorCount++
		lastError = time.Now().Format("2006-01-02 15:04:05")
		lastErrorMsg = errorMessage
		sendNotification("error", fmt.Sprintf("HA Script Error - %s", errorMessage), errorMessage)
	}
}

func dryRunPrefix() string {
	if dryRun {
		return "[dry run] "
	}
	return ""
}

func updateDisplay() {
	clearScreen()
	if dryRun {
		color.Red("DRY RUN MODE ENABLED")
	}
	color.Cyan("Script Start: %s", scriptStart)
	color.Cyan("Checks: %d", checkCount)
	color.Cyan("Restarts: %d", restartCount)
	color.Cyan("Errors: %d", errorCount)
	color.Cyan("Last Update: %s", lastUpdate)
	color.Cyan("Last Restart: %s", lastRestart)
	color.Cyan("Last Error: %s - %s", lastError, lastErrorMsg)
	fmt.Println()
	color.Cyan("Press 'R' to force a restart. Press 'S' to shutdown. Press Ctrl+C to exit...")
}

func clearScreen() {
	fmt.Print("\033[H\033[2J")
}

func main() {
	checkCount = 0
	restartCount = 0
	errorCount = 0

	logMessage("********** Home Assistant monitoring script started **********")
	sendNotification("launched", "Script launched", "")

	// Increment the check count before the initial check
	checkCount++
	lastUpdate = time.Now().Format("2006-01-02 15:04:05")

	haResponsive := checkHomeAssistant()
	if haResponsive {
		logMessage(fmt.Sprintf("%sHome Assistant is responsive at startup.", dryRunPrefix()))
	} else {
		logMessage(fmt.Sprintf("%sHome Assistant is not responsive at startup.", dryRunPrefix()))
		vmRunning := checkVMRunning()
		if vmRunning {
			logMessage(fmt.Sprintf("%sVM is running. Checking HA responsiveness every minute for up to 5 minutes.", dryRunPrefix()))
			waitedTime := 0
			for waitedTime < checkResponsiveMax && !haResponsive {
				time.Sleep(checkResponsiveWait)
				waitedTime++
				haResponsive = checkHomeAssistant()
				if haResponsive {
					logMessage(fmt.Sprintf("%sHome Assistant became responsive after %d minutes.", dryRunPrefix(), waitedTime))
				} else {
					logMessage(fmt.Sprintf("%sHome Assistant is still not responsive after %d minutes.", dryRunPrefix(), waitedTime))
				}
			}
		}
		if !haResponsive {
			logMessage(fmt.Sprintf("%sHome Assistant did not become responsive after waiting. Restarting the VM.", dryRunPrefix()))
			restartVirtualBoxVM()
		}
	}

	go func() {
		ticker := time.NewTicker(checkInterval)
		defer ticker.Stop()

		for range ticker.C {
			checkCount++
			lastUpdate = time.Now().Format("2006-01-02 15:04:05")
			if !checkHomeAssistant() {
				logMessage(fmt.Sprintf("%sHome Assistant is unresponsive. Checking responsiveness for 5 minutes.", dryRunPrefix()))
				waitedTime := 0
				haResponsive := false
				for waitedTime < checkResponsiveMax && !haResponsive {
					time.Sleep(checkResponsiveWait)
					waitedTime++
					haResponsive = checkHomeAssistant()
					if haResponsive {
						logMessage(fmt.Sprintf("%sHome Assistant became responsive after %d minutes.", dryRunPrefix(), waitedTime))
					} else {
						logMessage(fmt.Sprintf("%sHome Assistant is still not responsive after %d minutes.", dryRunPrefix(), waitedTime))
					}
				}
				if !haResponsive {
					restartCount++
					logMessage(fmt.Sprintf("%sHome Assistant did not become responsive after waiting. Restarting the VM.", dryRunPrefix()))
					restartVirtualBoxVM()
				}
			} else {
				if debug {
					logMessage(fmt.Sprintf("%sHome Assistant is responsive.", dryRunPrefix()))
				}
			}
			updateDisplay()
		}
	}()

	if err := keyboard.Open(); err != nil {
		panic(err)
	}
	defer keyboard.Close()

	updateDisplay()

	for {
		char, key, err := keyboard.GetKey()
		if err != nil {
			log.Fatalf("Failed to read key: %v", err)
		}

		if key == keyboard.KeyEsc || key == keyboard.KeyCtrlC {
			logMessage("Received interrupt signal. Exiting gracefully...")
			os.Exit(0)
		}

		switch char {
		case 'R', 'r':
			restartCount++
			lastRestart = time.Now().Format("2006-01-02 15:04:05")
			logMessage("Manual restart triggered.")
			restartVirtualBoxVM()
			updateDisplay()
		case 'S', 's':
			logMessage("Manual shutdown triggered.")
			shutdownVirtualBoxVM()
			sendNotification("shutdown", "Home Assistant VM is shutting down", "")
			updateDisplay()
		}
	}
}
