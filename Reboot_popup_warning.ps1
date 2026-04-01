############################################################
# Proactive IT - Reboot Warning Popup
#
# Launched 2 minutes before the scheduled reboot.
# Shows a live countdown and a close button.
############################################################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:remaining = 120   # 2 minutes in seconds

############################################################
# SECTION 1 - Create Form
############################################################
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Reboot Warning"
$form.Size            = New-Object System.Drawing.Size(300, 200)
$form.StartPosition   = "CenterScreen"
$form.Topmost         = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false


############################################################
# SECTION 2 - Warning Label
############################################################
$warningLabel            = New-Object System.Windows.Forms.Label
$warningLabel.Text       = "Your device will reboot in:"
$warningLabel.Location   = New-Object System.Drawing.Point(10, 18)
$warningLabel.Size       = New-Object System.Drawing.Size(280, 22)
$warningLabel.TextAlign  = "MiddleCenter"
$warningLabel.Font       = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($warningLabel)


############################################################
# SECTION 3 - Countdown Display
############################################################
$countdownLabel           = New-Object System.Windows.Forms.Label
$countdownLabel.Text      = "2:00"
$countdownLabel.Location  = New-Object System.Drawing.Point(10, 45)
$countdownLabel.Size      = New-Object System.Drawing.Size(280, 75)
$countdownLabel.TextAlign = "MiddleCenter"
$countdownLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 36, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($countdownLabel)


############################################################
# SECTION 4 - Close Button (centered)
############################################################
$closeButton          = New-Object System.Windows.Forms.Button
$closeButton.Text     = "Close"
$closeButton.Width    = 80
$closeButton.Height   = 28
$closeButton.Location = New-Object System.Drawing.Point(110, 132)
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)


############################################################
# SECTION 5 - Countdown Timer (1 second interval)
############################################################
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


############################################################
# SECTION 6 - Cleanup and Show
############################################################
$form.Add_FormClosed({
    $countdownTimer.Stop()
    $countdownTimer.Dispose()
})

$form.Add_Shown({ $form.Activate(); $countdownTimer.Start() })
[void]$form.ShowDialog()
