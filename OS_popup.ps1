############################################################
# Proactive IT Popup Script
#
# Creates a popup window with:
#  - Logo at the top (downloaded from URL)
#  - Message text
#  - Two buttons
#       Agree  -> shows confirmation message
#       Close  -> closes popup with no action
#
# Modular and commented for easy editing.
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
$PopupMessage = "Hello, your device appears to be missing important Windows updates. Installing updates helps keep your device secure and running smoothly. 

 Select a time below and click 'Agree' to schedule your update.
 NOTE: If this is a laptop, ensure it's plugged in."
$LogoURL      = "https://proactiveway.com/wp-content/uploads/2022/12/1.jpg"

$FormWidth    = 420
$FormHeight   = 380

# Temp file path for downloaded logo
$TempLogoPath = Join-Path $env:TEMP "proactive_logo.jpg"

# Update script written to disk when user agrees; defined here to avoid
# here-string parsing issues inside event scriptblocks.
$UpdateScriptDir     = "$env:ProgramData\ProactiveIT"
$UpdateScriptPath    = "$UpdateScriptDir\RunWindowsUpdate.ps1"
$UpdateScriptContent = @'
$session  = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$result   = $searcher.Search("IsInstalled=0 and Type='Software'")

if ($result.Updates.Count -gt 0) {
    $downloader         = $session.CreateUpdateDownloader()
    $downloader.Updates = $result.Updates
    $downloader.Download()

    $installer         = $session.CreateUpdateInstaller()
    $installer.Updates = $result.Updates
    $installer.Install()
}
'@


############################################################
# SECTION 3 — Download Logo Image
# Uses ErrorAction Stop so failures are caught properly.
############################################################
$LogoLoaded = $false

try {
    # Force modern TLS in case older PowerShell defaults cause issues
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
# Only adds the image if the download succeeded.
############################################################

$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.Location = New-Object System.Drawing.Point(10,10)
$pictureBox.Size = New-Object System.Drawing.Size(380,80)
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
$label.Size = New-Object System.Drawing.Size(360, 100)
$label.TextAlign = "MiddleCenter"
$label.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$form.Controls.Add($label)


############################################################
# SECTION 6b — Time Picker (Label + ComboBox)
############################################################
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = "Schedule update time:"
$timeLabel.Location = New-Object System.Drawing.Point(20, 210)
$timeLabel.Size = New-Object System.Drawing.Size(160, 20)
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$form.Controls.Add($timeLabel)

$timeComboBox = New-Object System.Windows.Forms.ComboBox
$timeComboBox.Location = New-Object System.Drawing.Point(190, 207)
$timeComboBox.Size = New-Object System.Drawing.Size(180, 26)
$timeComboBox.DropDownStyle = "DropDownList"
$timeComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)

@("5:00 PM","6:00 PM","7:00 PM","8:00 PM","9:00 PM","10:00 PM","11:00 PM") | ForEach-Object {
    [void]$timeComboBox.Items.Add($_)
}
$timeComboBox.SelectedIndex = 2   # Default: 7:00 PM

$form.Controls.Add($timeComboBox)

############################################################
# SECTION 7 — Agree Button
# Registers a scheduled task to install missing OS updates
# at the user-selected time, running as SYSTEM.
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

    # Parse selected time into today's trigger datetime
    $parsedTime  = [datetime]::ParseExact(
        $selectedTime.ToString(),
        "h:mm tt",
        [System.Globalization.CultureInfo]::InvariantCulture
    )

    $triggerTime = (Get-Date).Date.Add($parsedTime.TimeOfDay)

    $taskName = "ProactiveIT_OSUpdate"

    # Write the update script to a SYSTEM-accessible location
    $null = New-Item -Path $UpdateScriptDir -ItemType Directory -Force
    $UpdateScriptContent | Set-Content -Path $UpdateScriptPath -Encoding UTF8

    # Build scheduled task components
    $taskArgument = '-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $UpdateScriptPath

    $action = New-ScheduledTaskAction `
        -Execute "PowerShell.exe" `
        -Argument $taskArgument

    $trigger = New-ScheduledTaskTrigger -Once -At $triggerTime

    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    # Remove any prior version of this task, then register fresh
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Proactive IT - Install missing Windows updates"

    [System.Windows.Forms.MessageBox]::Show(
        "Your OS update is scheduled for $selectedTime tonight. Please keep your device on and plugged in, and save your work to prevent data loss.",
        "Update Scheduled",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    $form.Close()
})

$form.Controls.Add($AgreeButton)
############################################################
# SECTION 8 — Close Button
# Closes popup without performing any action.
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
# SECTION 9 — Cleanup When Form Closes
# Prevents file lock issues by closing the image stream.
############################################################
$form.Add_FormClosed({
    if ($pictureBox.Tag -is [System.IO.Stream]) {
        $pictureBox.Tag.Close()
        $pictureBox.Tag.Dispose()
    }
})


############################################################
# SECTION 10 — Show Popup
############################################################
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()