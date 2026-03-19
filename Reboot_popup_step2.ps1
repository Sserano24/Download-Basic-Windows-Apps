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
$ScheduleFilePath = "$env:ProgramData\ProactiveIT\reboot_schedule.json"
$TaskName         = "ProactiveIT_RebootPopup"


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
# SECTION 6 - Delete Schedule File (only after confirmed success)
############################################################
Remove-Item -Path $ScheduleFilePath -Force
Write-Host "Reboot schedule file deleted."
