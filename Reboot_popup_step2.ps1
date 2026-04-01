############################################################
# Proactive IT Reboot Popup - Step 2
#
# Reads reboot_schedule.json written by Reboot_popup_step1.ps1.
# If found, registers a one-time scheduled task that reboots
# the device at the saved time, then deletes the JSON file.
############################################################


############################################################
# SECTION 1 - Configuration
############################################################
$ScheduleFilePath  = "$env:ProgramData\ProactiveIT\reboot_schedule.json"
$ScriptDir         = "$env:ProgramData\ProactiveIT"
$TaskName          = "ProactiveIT_RebootPopup"
$WarningTaskName   = "ProactiveIT_RebootWarning"
$WarningScriptPath = "$ScriptDir\Reboot_popup_warning.ps1"


############################################################
# SECTION 2 - Check for Schedule File
############################################################
Write-Host "Looking for reboot schedule file at: $ScheduleFilePath"

if (-not (Test-Path $ScheduleFilePath)) {
    Write-Host "No reboot schedule file found. Run Reboot_popup_step1.ps1 first and click Agree."
    exit 1
}

Write-Host "Reboot schedule file found."


############################################################
# SECTION 3 - Parse Schedule File
############################################################
$schedule = Get-Content $ScheduleFilePath -Raw | ConvertFrom-Json
Write-Host "Parsed schedule - Time: $($schedule.ScheduledTime)  Date: $($schedule.ScheduledDate)"

$parsedTime = [datetime]::ParseExact(
    $schedule.ScheduledTime,
    "h:mm tt",
    [System.Globalization.CultureInfo]::InvariantCulture
)

$scheduledDate = [datetime]::ParseExact(
    $schedule.ScheduledDate,
    "yyyy-MM-dd",
    [System.Globalization.CultureInfo]::InvariantCulture
)

$triggerTime = $scheduledDate.Add($parsedTime.TimeOfDay)
Write-Host "Trigger datetime: $triggerTime"


############################################################
# SECTION 3b - Write Warning Popup Script to Disk
# Written here (top-level, not inside a scriptblock) to
# avoid here-string parsing issues.
# Runs as the logged-on user so the GUI appears on screen.
############################################################
$null = New-Item -Path $ScriptDir -ItemType Directory -Force

@'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:remaining = 120

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Reboot Warning"
$form.Size            = New-Object System.Drawing.Size(300, 200)
$form.StartPosition   = "CenterScreen"
$form.Topmost         = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false

$warningLabel           = New-Object System.Windows.Forms.Label
$warningLabel.Text      = "Your device will reboot in:"
$warningLabel.Location  = New-Object System.Drawing.Point(10, 18)
$warningLabel.Size      = New-Object System.Drawing.Size(280, 22)
$warningLabel.TextAlign = "MiddleCenter"
$warningLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($warningLabel)

$countdownLabel           = New-Object System.Windows.Forms.Label
$countdownLabel.Text      = "2:00"
$countdownLabel.Location  = New-Object System.Drawing.Point(10, 45)
$countdownLabel.Size      = New-Object System.Drawing.Size(280, 75)
$countdownLabel.TextAlign = "MiddleCenter"
$countdownLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 36, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($countdownLabel)

$closeButton          = New-Object System.Windows.Forms.Button
$closeButton.Text     = "Close"
$closeButton.Width    = 80
$closeButton.Height   = 28
$closeButton.Location = New-Object System.Drawing.Point(110, 132)
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)

$countdownTimer          = New-Object System.Windows.Forms.Timer
$countdownTimer.Interval = 1000

$countdownTimer.Add_Tick({
    $script:remaining--
    $minutes = [math]::Floor($script:remaining / 60)
    $seconds = $script:remaining % 60
    $countdownLabel.Text = "{0}:{1:D2}" -f $minutes, $seconds

    if ($script:remaining -le 0) {
        $countdownTimer.Stop()
        $form.Close()
    }
})

$form.Add_FormClosed({
    $countdownTimer.Stop()
    $countdownTimer.Dispose()
})

$form.Add_Shown({ $form.Activate(); $countdownTimer.Start() })
[void]$form.ShowDialog()
'@ | Set-Content -Path $WarningScriptPath -Encoding UTF8

Write-Host "Warning popup script written to: $WarningScriptPath"


############################################################
# SECTION 4 - Register Scheduled Reboot Task
############################################################

# Call shutdown.exe directly - SYSTEM has full access, no wrapper needed
$action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /t 0 /f"

$trigger = New-ScheduledTaskTrigger -Once -At $triggerTime

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit    (New-TimeSpan -Minutes 5) `
    -MultipleInstances     IgnoreNew `
    -WakeToRun `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

$principal = New-ScheduledTaskPrincipal `
    -UserId    "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel  Highest

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName    $TaskName `
    -Action      $action `
    -Trigger     $trigger `
    -Settings    $settings `
    -Principal   $principal `
    -Description "Proactive IT - Scheduled device reboot"


############################################################
# SECTION 5 - Verify Registration
############################################################
$registered = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $registered) {
    Write-Host "ERROR: Task registration failed. Ensure this script is running as Administrator."
    exit 1
}

Write-Host "Reboot task registered. Next run: $((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)"


############################################################
# SECTION 5b - Register Warning Popup Task
# Runs 2 minutes before reboot as BUILTIN\Users (interactive)
# so the countdown popup appears on the user's desktop.
############################################################
$warningAction = New-ScheduledTaskAction `
    -Execute  "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$WarningScriptPath`""

$warningTrigger = New-ScheduledTaskTrigger -Once -At $triggerTime.AddMinutes(-2)

$warningSettings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

$warningPrincipal = New-ScheduledTaskPrincipal `
    -GroupId   "BUILTIN\Users" `
    -RunLevel  Limited

Unregister-ScheduledTask -TaskName $WarningTaskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName    $WarningTaskName `
    -Action      $warningAction `
    -Trigger     $warningTrigger `
    -Settings    $warningSettings `
    -Principal   $warningPrincipal `
    -Description "Proactive IT - 2-minute reboot warning popup"

Write-Host "Warning popup task registered. Fires at: $($triggerTime.AddMinutes(-2))"


############################################################
# SECTION 6 - Delete Schedule File (only after confirmed success)
############################################################
Remove-Item -Path $ScheduleFilePath -Force
Write-Host "Reboot schedule file deleted."
