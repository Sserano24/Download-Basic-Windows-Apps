############################################################
# Proactive IT Reboot Popup - Step 1
#
# Creates a popup window with:
#  - Logo at the top (downloaded from URL)
#  - Message informing user a reboot is needed
#  - Time dropdown (future times only)
#  - Two buttons
#       Agree  -> saves chosen reboot time to JSON
#       Close  -> closes popup with no action
############################################################


############################################################
# SECTION 1 — Load Required GUI Libraries
############################################################
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


############################################################
# SECTION 2 — Configuration Variables
############################################################
$PopupTitle   = "Proactive IT"
$PopupMessage = "Hello, your device requires a reboot to complete pending maintenance.

 Select a time below and click 'Agree' to schedule your reboot.
 NOTE: Please save all open work before the scheduled time."
$LogoURL      = "https://proactiveway.com/wp-content/uploads/2022/12/1.jpg"

$FormWidth    = 450
$FormHeight   = 380

$TempLogoPath     = Join-Path $env:TEMP "proactive_logo.jpg"
$ScheduleFilePath = "$env:ProgramData\ProactiveIT\reboot_schedule.json"


############################################################
# SECTION 3 — Download Logo Image
############################################################
$LogoLoaded = $false

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Invoke-WebRequest `
        -Uri $LogoURL `
        -OutFile $TempLogoPath `
        -UseBasicParsing `
        -ErrorAction Stop

    if (Test-Path $TempLogoPath) {
        $LogoLoaded = $true
    }
}
catch {
    $LogoLoaded = $false
}


############################################################
# SECTION 4 — Create Main Popup Window
############################################################
$form = New-Object System.Windows.Forms.Form
$form.Text = $PopupTitle
$form.Size = New-Object System.Drawing.Size($FormWidth, $FormHeight)
$form.StartPosition = "CenterScreen"
$form.Topmost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false


############################################################
# SECTION 5 — Add Logo Image Control
############################################################
$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Location = New-Object System.Drawing.Point(10, 10)
$pictureBox.Size = New-Object System.Drawing.Size(380, 80)
$pictureBox.SizeMode = "Zoom"

if (Test-Path $TempLogoPath) {
    $pictureBox.Image = [System.Drawing.Image]::FromFile($TempLogoPath)
}

$form.Controls.Add($pictureBox)


############################################################
# SECTION 6 — Add Message Label
############################################################
$label = New-Object System.Windows.Forms.Label
$label.Text = $PopupMessage
$label.Location = New-Object System.Drawing.Point(20, 100)
$label.Size = New-Object System.Drawing.Size(410, 110)
$label.TextAlign = "MiddleCenter"
$label.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$form.Controls.Add($label)


############################################################
# SECTION 6b — Time Picker (Label + ComboBox)
############################################################
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "Schedule reboot time:"
$timeLabel.Location = New-Object System.Drawing.Point(20, 210)
$timeLabel.Size = New-Object System.Drawing.Size(160, 20)
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$form.Controls.Add($timeLabel)

$timeComboBox = New-Object System.Windows.Forms.ComboBox
$timeComboBox.Location = New-Object System.Drawing.Point(190, 207)
$timeComboBox.Size = New-Object System.Drawing.Size(210, 26)
$timeComboBox.DropDownStyle = "DropDownList"
$timeComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$now = Get-Date
foreach ($t in @("5:00 PM","5:30 PM","6:00 PM","7:00 PM","8:00 PM","9:15 PM","10:00 PM","11:00 PM")) {
    $candidate = $now.Date.Add(
        [datetime]::ParseExact($t, "h:mm tt", [System.Globalization.CultureInfo]::InvariantCulture).TimeOfDay
    )
    if ($candidate -gt $now) {
        [void]$timeComboBox.Items.Add($t)
    }
}

if ($timeComboBox.Items.Count -gt 0) {
    $timeComboBox.SelectedIndex = 0
} else {
    [void]$timeComboBox.Items.Add("No times available tonight")
    $timeComboBox.SelectedIndex = 0
    $timeComboBox.Enabled = $false
}

$form.Controls.Add($timeComboBox)


############################################################
# SECTION 7 — Agree Button
# Saves the chosen reboot time to disk for Step 2 to read.
############################################################
$AgreeButton = New-Object System.Windows.Forms.Button
$AgreeButton.Text = "Agree"
$AgreeButton.Width = 100
$AgreeButton.Height = 30
$AgreeButton.Location = New-Object System.Drawing.Point(100, 290)

$AgreeButton.Add_Click({
    $selectedTime = $timeComboBox.SelectedItem

    if (-not $selectedTime) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select a time before continuing.",
            "Time Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }

    # Save chosen reboot time to disk so Reboot_popup_step2 can read it
    $null = New-Item -Path (Split-Path $ScheduleFilePath) -ItemType Directory -Force
    [PSCustomObject]@{
        ScheduledTime = $selectedTime.ToString()
        ScheduledDate = (Get-Date -Format "yyyy-MM-dd")
    } | ConvertTo-Json | Set-Content -Path $ScheduleFilePath -Encoding UTF8

    [System.Windows.Forms.MessageBox]::Show(
        "Your device will reboot at $selectedTime. Please save all open work before then.",
        "Reboot Scheduled",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    $form.Close()
})

$form.Controls.Add($AgreeButton)

# Disable Agree if no future times were available
if (-not $timeComboBox.Enabled) { $AgreeButton.Enabled = $false }


############################################################
# SECTION 8 — Close Button
############################################################
$CloseButton = New-Object System.Windows.Forms.Button
$CloseButton.Text = "Close"
$CloseButton.Width = 100
$CloseButton.Height = 30
$CloseButton.Location = New-Object System.Drawing.Point(220, 290)

$CloseButton.Add_Click({
    $form.Close()
})

$form.Controls.Add($CloseButton)


############################################################
# SECTION 8b — Idle Timeout Timer
# Auto-closes after 7 hours of no user response.
# Cleans up any stale scheduled tasks and schedule file
# left behind by the previous day's step1/step2 run.
############################################################
$idleTimer = New-Object System.Windows.Forms.Timer
$idleTimer.Interval = 25200000   # 7 hours in milliseconds

$idleTimer.Add_Tick({
    $idleTimer.Stop()

    # Remove stale scheduled tasks from both popup workflows
    foreach ($task in @("ProactiveIT_RebootPopup", "ProactiveIT_RebootWarning", "ProactiveIT_UpdateAndReboot")) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
    }

    # Remove stale schedule files from both popup workflows
    foreach ($file in @($ScheduleFilePath, "$env:ProgramData\ProactiveIT\schedule.json")) {
        if (Test-Path $file) {
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        }
    }

    $form.Close()
})


############################################################
# SECTION 9 — Cleanup When Form Closes
############################################################
$form.Add_FormClosed({
    $idleTimer.Stop()
    $idleTimer.Dispose()
    if ($pictureBox.Tag -is [System.IO.Stream]) {
        $pictureBox.Tag.Close()
        $pictureBox.Tag.Dispose()
    }
})


############################################################
# SECTION 10 — Show Popup
############################################################
$form.Add_Shown({ $form.Activate(); $idleTimer.Start() })
[void]$form.ShowDialog()
