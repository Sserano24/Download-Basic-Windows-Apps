############################################################
# Proactive IT - Reboot Warning Popup
#
# Launched 2 minutes before the scheduled reboot.
# Shows a live countdown, a close button, and a cancel button.
# Works whether launched as SYSTEM or as a standard user.
############################################################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:remaining = 120   # 2 minutes in seconds

############################################################
# SECTION 1 - Colors and Fonts
############################################################
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


############################################################
# SECTION 2 - Create Form
############################################################
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Proactive IT"
$form.Size            = New-Object System.Drawing.Size(340, 250)
$form.StartPosition   = "CenterScreen"
$form.Topmost         = $true
$form.FormBorderStyle = "FixedDialog"
$form.BackColor       = $colorLight
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false


############################################################
# SECTION 3 - Blue Header Banner
############################################################
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


############################################################
# SECTION 4 - Subtext
############################################################
$subtextLabel           = New-Object System.Windows.Forms.Label
$subtextLabel.Text      = "Your device will restart in:"
$subtextLabel.Location  = New-Object System.Drawing.Point(0, 58)
$subtextLabel.Size      = New-Object System.Drawing.Size(340, 20)
$subtextLabel.TextAlign = "MiddleCenter"
$subtextLabel.ForeColor = $colorSubtext
$subtextLabel.Font      = $fontSubtext
$form.Controls.Add($subtextLabel)


############################################################
# SECTION 5 - Countdown Display
############################################################
$countdownLabel           = New-Object System.Windows.Forms.Label
$countdownLabel.Text      = "2:00"
$countdownLabel.Location  = New-Object System.Drawing.Point(0, 82)
$countdownLabel.Size      = New-Object System.Drawing.Size(340, 60)
$countdownLabel.TextAlign = "MiddleCenter"
$countdownLabel.ForeColor = $colorBlue
$countdownLabel.Font      = $fontCountdown
$form.Controls.Add($countdownLabel)


############################################################
# SECTION 6 - Save Work Reminder
############################################################
$noteLabel           = New-Object System.Windows.Forms.Label
$noteLabel.Text      = "Please save all open work before the reboot occurs."
$noteLabel.Location  = New-Object System.Drawing.Point(10, 148)
$noteLabel.Size      = New-Object System.Drawing.Size(320, 18)
$noteLabel.TextAlign = "MiddleCenter"
$noteLabel.ForeColor = $colorSubtext
$noteLabel.Font      = $fontNote
$form.Controls.Add($noteLabel)


############################################################
# SECTION 7 - Buttons (Close + Cancel Reboot)
############################################################
$closeButton                           = New-Object System.Windows.Forms.Button
$closeButton.Text                      = "Close"
$closeButton.Width                     = 115
$closeButton.Height                    = 30
$closeButton.Location                  = New-Object System.Drawing.Point(113, 175)
$closeButton.FlatStyle                 = "Flat"
$closeButton.BackColor                 = $colorBlue
$closeButton.ForeColor                 = $colorWhite
$closeButton.Font                      = $fontButton
$closeButton.FlatAppearance.BorderSize = 0
$closeButton.Add_Click({ $form.Close() })
$form.Controls.Add($closeButton)


############################################################
# SECTION 8 - Countdown Timer
# Turns red under 30 seconds.
############################################################
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


############################################################
# SECTION 9 - Cleanup and Show
############################################################
$form.Add_FormClosed({
    $countdownTimer.Stop()
    $countdownTimer.Dispose()
})

$form.Add_Shown({ $form.Activate(); $countdownTimer.Start() })
[void]$form.ShowDialog()
