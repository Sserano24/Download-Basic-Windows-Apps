############################################################
# Proactive IT - Reboot Warning Popup
#
# Launched 2 minutes before the scheduled reboot.
# Shows a live countdown, a reboot now button, and a cancel button.
# Works whether launched as SYSTEM or as a standard user.
############################################################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Hide the console window when running as SYSTEM
Add-Type -Name Window -Namespace Console -MemberDefinition @"
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("User32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
"@

$consolePtr = [Console.Window]::GetConsoleWindow()
if ($consolePtr -gt 0) {
    [void][Console.Window]::ShowWindow($consolePtr, 0)  # 0 = SW_HIDE
}

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
# SECTION 7 - Buttons (Reboot Now + Cancel Reboot)
############################################################
$rebootButton                           = New-Object System.Windows.Forms.Button
$rebootButton.Text                      = "Reboot Now"
$rebootButton.Width                     = 115
$rebootButton.Height                    = 30
$rebootButton.Location                  = New-Object System.Drawing.Point(20, 175)
$rebootButton.FlatStyle                 = "Flat"
$rebootButton.BackColor                 = $colorBlue
$rebootButton.ForeColor                 = $colorWhite
$rebootButton.Font                      = $fontButton
$rebootButton.FlatAppearance.BorderSize = 0
$rebootButton.Add_Click({
    try {
        # Unregister the warning task to prevent it from interfering
        Unregister-ScheduledTask -TaskName "ProactiveIT_RebootWarning" -Confirm:$false -ErrorAction SilentlyContinue
        # Trigger immediate restart
        shutdown.exe /r /t 0 /f
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to restart:`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})
$form.Controls.Add($rebootButton)

$cancelButton                           = New-Object System.Windows.Forms.Button
$cancelButton.Text                      = "Cancel Reboot"
$cancelButton.Width                     = 115
$cancelButton.Height                    = 30
$cancelButton.Location                  = New-Object System.Drawing.Point(205, 175)
$cancelButton.FlatStyle                 = "Flat"
$cancelButton.BackColor                 = $colorRed
$cancelButton.ForeColor                 = $colorWhite
$cancelButton.Font                      = $fontButton
$cancelButton.FlatAppearance.BorderSize = 0
$cancelButton.Add_Click({
    try {
        # Create a cancellation flag file - this is the main cancellation mechanism
        # The scheduled reboot wrapper will check this before executing
        $cancelFlagPath = "$env:ProgramData\ProactiveIT\cancel_reboot.flag"
        $cancelFlagDir = Split-Path $cancelFlagPath
        
        # Ensure the directory exists
        if (-not (Test-Path $cancelFlagDir)) {
            $null = New-Item -Path $cancelFlagDir -ItemType Directory -Force -ErrorAction SilentlyContinue
        }
        
        # Write the cancellation flag
        "CANCELLED_AT_$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content -Path $cancelFlagPath -Force -ErrorAction Stop
        Write-Host "Cancellation flag created at: $cancelFlagPath"
        
        # Try to unregister the warning task (non-admin should be able to do this for their own tasks)
        $unregWarning = $false
        try {
            Unregister-ScheduledTask -TaskName "ProactiveIT_RebootWarning" -Confirm:$false -ErrorAction Stop
            $unregWarning = $true
            Write-Host "Successfully unregistered ProactiveIT_RebootWarning task"
        } catch {
            Write-Host "Could not unregister warning task (this is OK, the cancellation flag will prevent reboot): $($_.Exception.Message)"
        }
        
        # Try to unregister the main reboot task (will likely fail due to SYSTEM privileges)
        $unregMain = $false
        try {
            Unregister-ScheduledTask -TaskName "ProactiveIT_RebootPopup" -Confirm:$false -ErrorAction Stop
            $unregMain = $true
            Write-Host "Successfully unregistered ProactiveIT_RebootPopup task"
        } catch {
            Write-Host "Could not unregister reboot task (this is OK, the cancellation flag will prevent reboot): $($_.Exception.Message)"
        }
        
        # Show success message
        [System.Windows.Forms.MessageBox]::Show(
            "The scheduled reboot has been cancelled.`n`nThe system will no longer restart at the scheduled time.",
            "Reboot Cancelled",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error during cancellation:`n$($_.Exception.Message)`n`nPlease contact your IT administrator.",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})
$form.Controls.Add($cancelButton)


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
