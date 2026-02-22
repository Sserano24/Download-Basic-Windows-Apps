<#
    install-apps.ps1
    - Checks status of common apps
    - Prompts which to install
    - Installs selected apps via winget silently with latest versions
#>

# Ensure script runs in PowerShell 7+ or Windows PowerShell with winget available
Write-Host "=== Workstation App Installer (winget) ===`n"

# 1. Define the apps and Winget IDs
$apps = @(
    @{
        Name = "Google Chrome"
        Id   = "Google.Chrome"
    },
    @{
        Name = "Adobe Acrobat Reader (64-bit)"
        Id   = "Adobe.Acrobat.Reader.64-bit"
    },
    @{
        Name = "Zoom Workplace"
        Id   = "Zoom.Zoom"
    },
    @{
        Name = "Microsoft Remote Desktop"
        Id   = "Microsoft.RemoteDesktopClient"
    },
    @{
        Name = "Microsoft 365 Apps (Word, Excel, PowerPoint, Outlook, OneNote)"
        Id   = "Microsoft.Office"
    },
    @{
        Name = "Microsoft OneDrive"
        Id   = "Microsoft.OneDrive"
    },
    @{
        Name = "Microsoft Teams"
        Id   = "Microsoft.Teams"
    }
)

# Helper: Check if app is installed with winget
function Test-AppInstalled {
    param(
        [string]$WingetId
    )
    # winget list is slow but reliable; we filter by Id
    $result = winget list --id $WingetId --source winget 2>$null
    if ($LASTEXITCODE -eq 0 -and $result -match $WingetId) {
        return $true
    }
    return $false
}

# Helper: Get Y/N response with RDP compatibility
function Get-YesNoResponse {
    param(
        [string]$Prompt
    )
    while ($true) {
        Write-Host $Prompt -NoNewline
        Write-Host " (1=Yes, 2=No): " -NoNewline
        $response = Read-Host
        switch ($response.Trim()) {
            "1" { return $true }
            "2" { return $false }
            "Y" { return $true }
            "N" { return $false }
            default {
                Write-Host "Please enter 1 for Yes or 2 for No."
            }
        }
    }
}

# 2. Check current install status
Write-Host "Checking current app status (this may take a moment...)`n"

$appsStatus = foreach ($app in $apps) {
    $installed = Test-AppInstalled -WingetId $app.Id
    [PSCustomObject]@{
        Name      = $app.Name
        Id        = $app.Id
        Installed = $installed
    }
}

# 3. Display status
Write-Host "=== Application Status ==="
foreach ($app in $appsStatus) {
    if ($app.Installed) {
        Write-Host "[Installed]    $($app.Name)"
    } else {
        Write-Host "[Not installed] $($app.Name)"
    }
}
Write-Host ""

# 4. Build list of apps that are NOT installed
$notInstalled = $appsStatus | Where-Object { -not $_.Installed }

if (-not $notInstalled) {
    Write-Host "All apps in the list are already installed. Nothing to do."
    return
}

Write-Host "The following apps are NOT installed and can be installed:`n"
$notInstalled | ForEach-Object {
    Write-Host " - $($_.Name)"
}

Write-Host ""

# 5. Prompt user per-app: install? (Y/N)
$appsToInstall = @()

foreach ($app in $notInstalled) {
    if (Get-YesNoResponse "Do you want to install '$($app.Name)'?") {
        $appsToInstall += $app
    } else {
        Write-Host "Skipping $($app.Name)."
    }
}

if (-not $appsToInstall) {
    Write-Host "`nNo apps selected for installation. Exiting."
    return
}

Write-Host "`n=== Final install list ==="
$appsToInstall | ForEach-Object {
    Write-Host " - $($_.Name)  (winget id: $($_.Id))"
}

# 6. Confirm before starting download & install
Write-Host ""
if (-not (Get-YesNoResponse "Proceed with downloading and silently installing these apps?")) {
    Write-Host "Operation cancelled."
    return
}

Write-Host "`nStarting installations using winget...`n"

# 7. Install selected apps via winget silently
foreach ($app in $appsToInstall) {
    Write-Host "Installing $($app.Name) ..."
    # /silent behavior flags:
    #   --silent: no UI
    #   --accept-package-agreements --accept-source-agreements: auto-accepts
    winget install --id $($app.Id) `
        --source winget `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully installed $($app.Name).`n"
    } else {
        Write-Host "Failed to install $($app.Name). Check output above for error details.`n"
    }
}

Write-Host "All done!"
Write-Host ""
if (Get-YesNoResponse "Would you like to reboot the computer now to complete the installations?") {
    Write-Host "Rebooting now..."
    Restart-Computer -Force
} else {
    Write-Host "Reboot cancelled. Please reboot manually when ready."
}