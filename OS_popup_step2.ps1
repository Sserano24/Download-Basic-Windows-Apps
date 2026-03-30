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
# SECTION 4 - Write Update + Reboot Script to Disk
# Uses PSWindowsUpdate for patching. Single-quote here-string
# preserves all $ signs so they evaluate at task runtime.
############################################################
$null = New-Item -Path $UpdateScriptDir -ItemType Directory -Force

@'
$LogPath = "$env:ProgramData\ProactiveIT\update_log.txt"

function Write-Log {
    param([string]$Message)
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

# -------------------------------------------------------
# TASK START - proof the device was on at scheduled time
# -------------------------------------------------------
Write-Log "=========================================="
Write-Log "SCHEDULED TASK STARTED SUCCESSFULLY"
Write-Log "Device was powered on at the scheduled time."
Write-Log "=========================================="

# -------------------------------------------------------
# ENSURE PSWINDOWSUPDATE
# -------------------------------------------------------
Write-Log "Checking for PSWindowsUpdate module..."
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Log "PSWindowsUpdate not found - installing..."
    try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        }
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -ErrorAction Stop
        Write-Log "PSWindowsUpdate installed successfully."
    } catch {
        Write-Log "ERROR: Failed to install PSWindowsUpdate - $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Log "PSWindowsUpdate module found."
}

Import-Module PSWindowsUpdate -Force

# -------------------------------------------------------
# SCAN FOR UPDATES
# -------------------------------------------------------
Write-Log "------------------------------------------"
Write-Log "UPDATE SCAN STARTING"
Write-Log "------------------------------------------"

try {
    $updates = Get-WindowsUpdate -AcceptAll -ErrorAction Stop
} catch {
    Write-Log "ERROR: Update scan failed - $($_.Exception.Message)"
    exit 1
}

if ($updates.Count -eq 0) {
    Write-Log "No missing updates found. Nothing to install."
    exit 0
}

Write-Log "Found $($updates.Count) update(s) to install:"
foreach ($u in $updates) {
    Write-Log "  - $($u.Title)"
}

# -------------------------------------------------------
# INSTALL UPDATES
# -------------------------------------------------------
Write-Log "------------------------------------------"
Write-Log "UPDATE INSTALLATION STARTING"
Write-Log "------------------------------------------"

try {
    $result = Install-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop
} catch {
    Write-Log "ERROR: Update installation failed - $($_.Exception.Message)"
    exit 1
}

Write-Log "Installation results:"
foreach ($r in $result) {
    Write-Log "  [$($r.Result)] $($r.Title)"
}

# -------------------------------------------------------
# REBOOT IF REQUIRED
# -------------------------------------------------------
$rebootRequired = Get-WURebootStatus -Silent
if ($rebootRequired) {
    Write-Log "REBOOT REQUIRED - rebooting now..."
    Restart-Computer -Force
} else {
    Write-Log "No reboot required. Update process complete."
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
