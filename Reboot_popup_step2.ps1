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

$colorBlue    = [System.Drawing.Color]::FromArgb(31, 97, 141)
$colorRed     = [System.Drawing.Color]::FromArgb(192, 57, 43)
$colorWhite   = [System.Drawing.Color]::White
$colorLight   = [System.Drawing.Color]::FromArgb(245, 245, 245)
$colorSubtext = [System.Drawing.Color]::FromArgb(100, 100, 100)

$fontHeading   = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fontSubtext   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontCountdown = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$fontNote      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$fontButton    = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Proactive IT"
$form.Size            = New-Object System.Drawing.Size(340, 250)
$form.StartPosition   = "CenterScreen"
$form.Topmost         = $true
$form.FormBorderStyle = "FixedDialog"
$form.BackColor       = $colorLight
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false

$headerPanel           = New-Object System.Windows.Forms.Panel
$headerPanel.Location  = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size      = New-Object System.Drawing.Size(340, 48)
$headerPanel.BackColor = $colorBlue
$form.Controls.Add($headerPanel)

$headerLabel           = New-Object System.Windows.Forms.Label
$headerLabel.Text      = "Reboot Scheduled"
$headerLabel.Location  = New-Object System.Drawing.Point(0, 0)
$headerLabel.Size      = New-Object System.Drawing.Size(340, 48)
$headerLabel.TextAlign = "MiddleCenter"
$headerLabel.ForeColor = $colorWhite
$headerLabel.Font      = $fontHeading
$headerPanel.Controls.Add($headerLabel)

$subtextLabel           = New-Object System.Windows.Forms.Label
$subtextLabel.Text      = "Your device will restart in:"
$subtextLabel.Location  = New-Object System.Drawing.Point(0, 58)
$subtextLabel.Size      = New-Object System.Drawing.Size(340, 20)
$subtextLabel.TextAlign = "MiddleCenter"
$subtextLabel.ForeColor = $colorSubtext
$subtextLabel.Font      = $fontSubtext
$form.Controls.Add($subtextLabel)

$countdownLabel           = New-Object System.Windows.Forms.Label
$countdownLabel.Text      = "2:00"
$countdownLabel.Location  = New-Object System.Drawing.Point(0, 82)
$countdownLabel.Size      = New-Object System.Drawing.Size(340, 60)
$countdownLabel.TextAlign = "MiddleCenter"
$countdownLabel.ForeColor = $colorBlue
$countdownLabel.Font      = $fontCountdown
$form.Controls.Add($countdownLabel)

$noteLabel           = New-Object System.Windows.Forms.Label
$noteLabel.Text      = "Please save all open work before the reboot occurs."
$noteLabel.Location  = New-Object System.Drawing.Point(10, 148)
$noteLabel.Size      = New-Object System.Drawing.Size(320, 18)
$noteLabel.TextAlign = "MiddleCenter"
$noteLabel.ForeColor = $colorSubtext
$noteLabel.Font      = $fontNote
$form.Controls.Add($noteLabel)

$closeButton                           = New-Object System.Windows.Forms.Button
$closeButton.Text                      = "Close"
$closeButton.Width                     = 115
$closeButton.Height                    = 30
$closeButton.Location                  = New-Object System.Drawing.Point(20, 175)
$closeButton.FlatStyle                 = "Flat"
$closeButton.BackColor                 = $colorBlue
$closeButton.ForeColor                 = $colorWhite
$closeButton.Font                      = $fontButton
$closeButton.FlatAppearance.BorderSize = 0
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)

$cancelButton                           = New-Object System.Windows.Forms.Button
$cancelButton.Text                      = "Cancel Reboot"
$cancelButton.Width                     = 120
$cancelButton.Height                    = 30
$cancelButton.Location                  = New-Object System.Drawing.Point(195, 175)
$cancelButton.FlatStyle                 = "Flat"
$cancelButton.BackColor                 = $colorRed
$cancelButton.ForeColor                 = $colorWhite
$cancelButton.Font                      = $fontButton
$cancelButton.FlatAppearance.BorderSize = 0
$cancelButton.Add_Click({
    Unregister-ScheduledTask -TaskName "ProactiveIT_RebootPopup"  -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "ProactiveIT_RebootWarning" -Confirm:$false -ErrorAction SilentlyContinue
    $form.Close()
})
$form.Controls.Add($cancelButton)

$countdownTimer          = New-Object System.Windows.Forms.Timer
$countdownTimer.Interval = 1000

$countdownTimer.Add_Tick({
    $script:remaining--
    $minutes = [math]::Floor($script:remaining / 60)
    $seconds = $script:remaining % 60
    $countdownLabel.Text = "{0}:{1:D2}" -f $minutes, $seconds

    if ($script:remaining -le 30) {
        $countdownLabel.ForeColor = $colorRed
        $closeButton.BackColor    = $colorRed
    }

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
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$WarningScriptPath`""

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
