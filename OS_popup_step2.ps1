############################################################
# Proactive IT - Step 2: Schedule Updates + Reboot
#
# Reads schedule.json written by OS_popup.ps1.
# If found, writes an update script to disk, registers a
# one-time scheduled task that installs missing OS updates
# and reboots when done, then deletes the JSON file.
############################################################


############################################################
# SECTION 1 — Configuration
############################################################
$ScheduleFilePath  = "$env:ProgramData\ProactiveIT\schedule.json"
$TaskName          = "ProactiveIT_UpdateAndReboot"
$UpdateScriptDir   = "$env:ProgramData\ProactiveIT"
$UpdateScriptPath  = "$UpdateScriptDir\RunUpdateAndReboot.ps1"


############################################################
# SECTION 2 — Check for Schedule File
############################################################
if (-not (Test-Path $ScheduleFilePath)) {
    Write-Host "No schedule file found at $ScheduleFilePath. Nothing to do."
    exit 0
}


############################################################
# SECTION 3 — Parse Schedule File
############################################################
$schedule = Get-Content $ScheduleFilePath -Raw | ConvertFrom-Json

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


############################################################
# SECTION 4 — Write Update + Reboot Script to Disk
# Defined and written here (not inside a scriptblock) to
# avoid here-string parsing issues.
############################################################
$null = New-Item -Path $UpdateScriptDir -ItemType Directory -Force

@'
$session  = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$result   = $searcher.Search("IsInstalled=0 and Type='Software'")

if ($result.Updates.Count -gt 0) {
    $updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl

    for ($i = 0; $i -lt $result.Updates.Count; $i++) {
        $update = $result.Updates.Item($i)
        if (-not $update.EulaAccepted) {
            $update.AcceptEula()
        }
        $null = $updatesToDownload.Add($update)
    }

    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $updatesToDownload
    $downloadResult = $downloader.Download()

    $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

    for ($i = 0; $i -lt $updatesToDownload.Count; $i++) {
        $update = $updatesToDownload.Item($i)
        if ($update.IsDownloaded) {
            $null = $updatesToInstall.Add($update)
        }
    }

    if ($updatesToInstall.Count -gt 0) {
        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $updatesToInstall
        $installResult = $installer.Install()

        if ($installResult.RebootRequired) {
            Restart-Computer -Force
        }
    }
}
'@ | Set-Content -Path $UpdateScriptPath -Encoding UTF8

############################################################
# SECTION 5 — Register Scheduled Task
############################################################
$action = New-ScheduledTaskAction `
    -Execute  "PowerShell.exe" `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$UpdateScriptPath`""

$trigger = New-ScheduledTaskTrigger -Once -At $triggerTime

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 3) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId      "SYSTEM" `
    -LogonType   ServiceAccount `
    -RunLevel    Highest

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName    $TaskName `
    -Action      $action `
    -Trigger     $trigger `
    -Settings    $settings `
    -Principal   $principal `
    -Description "Proactive IT - Install missing OS updates and reboot"

Write-Host "Update and reboot scheduled for $($schedule.ScheduledTime) on $($schedule.ScheduledDate)."


############################################################
# SECTION 6 — Delete Schedule File
############################################################
Remove-Item -Path $ScheduleFilePath -Force
Write-Host "Schedule file deleted."
