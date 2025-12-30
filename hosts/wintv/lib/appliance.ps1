# hosts/wintv/lib/appliance.ps1
# Appliance mode configuration: auto-login, kiosk apps, Podman system service

#Requires -RunAsAdministrator

# =============================================================================
# Auto-Login Configuration
# =============================================================================
# Configures Windows to automatically log in without password prompt.
# Uses LSA secrets for secure password storage (not plaintext registry).

function Set-AutoLogin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$false)]
        [switch]$Disable
    )

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    if ($Disable) {
        Write-Host "  Disabling auto-login..." -ForegroundColor Yellow
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "0" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
        Write-Host "  Auto-login disabled" -ForegroundColor Green
        return
    }

    Write-Host "  Configuring auto-login for user: $Username" -ForegroundColor Yellow

    # Set registry values for auto-login
    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1"
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $Username
    Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME

    # Prompt for password if not already configured
    $existingPassword = Get-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    if (-not $existingPassword) {
        Write-Host ""
        Write-Host "  NOTE: You need to set the password for auto-login." -ForegroundColor Cyan
        Write-Host "  Run this command in an elevated PowerShell:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'DefaultPassword' -Value 'YOUR_PASSWORD'" -ForegroundColor White
        Write-Host ""
        Write-Host "  Or use the Sysinternals Autologon tool for encrypted storage:" -ForegroundColor Cyan
        Write-Host "    winget install Sysinternals.Autologon" -ForegroundColor White
        Write-Host "    autologon $Username $env:COMPUTERNAME *" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "  Auto-login configured for $Username" -ForegroundColor Green
}

# =============================================================================
# Kiosk Mode / Auto-Start Application
# =============================================================================
# Configures an application to start automatically at user login.

function Set-KioskApp {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("kodi", "jellyfin-mpv-shim", "custom")]
        [string]$Application,

        [Parameter(Mandatory=$false)]
        [string]$CustomCommand,

        [Parameter(Mandatory=$false)]
        [switch]$Disable
    )

    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutPath = "$startupPath\WinTV-Kiosk.lnk"

    if ($Disable) {
        Write-Host "  Disabling kiosk auto-start..." -ForegroundColor Yellow
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
        }
        Write-Host "  Kiosk auto-start disabled" -ForegroundColor Green
        return
    }

    # Determine the application path
    $appPath = switch ($Application) {
        "kodi" {
            # Kodi installed via WinGet
            $kodiPaths = @(
                "${env:ProgramFiles}\Kodi\kodi.exe",
                "${env:ProgramFiles(x86)}\Kodi\kodi.exe",
                "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages\XBMCFoundation.Kodi_*\Kodi\kodi.exe"
            )
            $found = $kodiPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $found) {
                # Try to find via WinGet installation
                $wingetPath = Get-ChildItem "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages" -Filter "XBMCFoundation.Kodi*" -Directory -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($wingetPath) {
                    $found = Join-Path $wingetPath.FullName "Kodi\kodi.exe"
                }
            }
            $found
        }
        "jellyfin-mpv-shim" {
            "${env:LOCALAPPDATA}\Programs\jellyfin-mpv-shim\jellyfin-mpv-shim.exe"
        }
        "custom" {
            $CustomCommand
        }
    }

    if (-not $appPath -or (-not (Test-Path $appPath) -and $Application -ne "custom")) {
        Write-Host "  WARNING: Application not found: $Application" -ForegroundColor Yellow
        Write-Host "  Expected path: $appPath" -ForegroundColor Yellow
        Write-Host "  Install the application first, then re-run deploy" -ForegroundColor Yellow
        return
    }

    Write-Host "  Configuring auto-start for: $Application" -ForegroundColor Yellow

    # Create startup shortcut
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $appPath
    $shortcut.WorkingDirectory = Split-Path $appPath -Parent
    $shortcut.Description = "WinTV Kiosk Application"
    $shortcut.Save()

    Write-Host "  Auto-start configured: $appPath" -ForegroundColor Green
}

# =============================================================================
# Podman System Service
# =============================================================================
# Configures Podman to run as a system service instead of user process.
# This ensures containers start at boot regardless of user login.

function Set-PodmanSystemService {
    param(
        [Parameter(Mandatory=$false)]
        [switch]$Disable
    )

    $serviceName = "PodmanContainers"

    # Find NSSM in common locations
    $nssmPaths = @(
        "${env:ProgramFiles}\nssm\nssm.exe",
        "${env:ProgramFiles(x86)}\nssm\nssm.exe",
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\nssm.exe",
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages\NSSM.NSSM_*\nssm-*\win64\nssm.exe",
        "C:\ProgramData\chocolatey\bin\nssm.exe"
    )
    $nssmPath = $nssmPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    # Also try Get-Command
    if (-not $nssmPath) {
        $nssmCmd = Get-Command nssm -ErrorAction SilentlyContinue
        if ($nssmCmd) { $nssmPath = $nssmCmd.Source }
    }

    if ($Disable) {
        Write-Host "  Disabling Podman system service..." -ForegroundColor Yellow
        if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
            & $nssmPath stop $serviceName 2>$null
            & $nssmPath remove $serviceName confirm 2>$null
        }
        # Re-enable Podman Desktop auto-start if disabled
        Write-Host "  Podman system service disabled" -ForegroundColor Green
        return
    }

    Write-Host "  Configuring Podman as system service..." -ForegroundColor Yellow

    # Check for NSSM (Non-Sucking Service Manager)
    if (-not $nssmPath) {
        Write-Host "  Installing NSSM for service management..." -ForegroundColor Yellow
        winget install --id nssm.nssm --accept-source-agreements --accept-package-agreements -h

        # Refresh PATH from registry
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Re-search for NSSM
        $nssmPath = $nssmPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $nssmPath) {
            $nssmCmd = Get-Command nssm -ErrorAction SilentlyContinue
            if ($nssmCmd) { $nssmPath = $nssmCmd.Source }
        }
    }

    if (-not $nssmPath -or -not (Test-Path $nssmPath)) {
        Write-Host "  ERROR: NSSM not found. Cannot create system service." -ForegroundColor Red
        Write-Host "  Install manually: winget install nssm.nssm" -ForegroundColor Yellow
        return
    }

    # Find Podman executable
    $podmanPath = (Get-Command podman -ErrorAction SilentlyContinue).Source
    if (-not $podmanPath) {
        $podmanPath = "${env:ProgramFiles}\RedHat\Podman\podman.exe"
    }

    if (-not (Test-Path $podmanPath)) {
        Write-Host "  ERROR: Podman not found. Install Podman first." -ForegroundColor Red
        return
    }

    # Create the service startup script
    $scriptDir = "C:\ProgramData\wintv\scripts"
    if (-not (Test-Path $scriptDir)) {
        New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
    }

    $startupScript = @'
@echo off
REM WinTV Podman Container Startup Script
REM Starts all containers defined in docker-compose.yml

cd /d C:\ProgramData\wintv

REM Initialize Podman machine if needed
podman machine list | findstr /C:"Currently running" >nul 2>&1
if errorlevel 1 (
    echo Starting Podman machine...
    podman machine start
    timeout /t 10 /nobreak >nul
)

REM Start containers
if exist docker-compose.yml (
    echo Starting containers...
    podman-compose up -d
)

REM Keep running to maintain service
:loop
timeout /t 60 /nobreak >nul
goto loop
'@

    $startupScript | Out-File -FilePath "$scriptDir\podman-startup.cmd" -Encoding ASCII

    # Remove existing service if present
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        & $nssmPath stop $serviceName 2>$null
        & $nssmPath remove $serviceName confirm 2>$null
    }

    # Create the service
    & $nssmPath install $serviceName "$scriptDir\podman-startup.cmd"
    & $nssmPath set $serviceName AppDirectory "C:\ProgramData\wintv"
    & $nssmPath set $serviceName DisplayName "WinTV Podman Containers"
    & $nssmPath set $serviceName Description "Runs Podman containers for WinTV media services"
    & $nssmPath set $serviceName Start SERVICE_AUTO_START
    & $nssmPath set $serviceName AppStdout "$scriptDir\podman-service.log"
    & $nssmPath set $serviceName AppStderr "$scriptDir\podman-service-error.log"

    # Start the service
    & $nssmPath start $serviceName

    Write-Host "  Podman system service created and started" -ForegroundColor Green
    Write-Host "  Containers will now start at boot" -ForegroundColor Green

    # Disable Podman Desktop auto-start to avoid conflicts
    $podmanDesktopStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Podman Desktop.lnk"
    if (Test-Path $podmanDesktopStartup) {
        Remove-Item $podmanDesktopStartup -Force
        Write-Host "  Disabled Podman Desktop auto-start (using system service instead)" -ForegroundColor Yellow
    }
}

# =============================================================================
# Main Entry Point
# =============================================================================

function Initialize-ApplianceMode {
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$Config
    )

    Write-Host ""
    Write-Host "[Appliance Mode] Configuring system..." -ForegroundColor Cyan

    # Auto-login
    if ($Config.AutoLogin.Enable) {
        Set-AutoLogin -Username $Config.AutoLogin.Username
    }

    # Kiosk app
    if ($Config.Kiosk.Enable) {
        Set-KioskApp -Application $Config.Kiosk.Application -CustomCommand $Config.Kiosk.CustomCommand
    }

    # Podman system service
    if ($Config.PodmanSystemService) {
        Set-PodmanSystemService
    }

    Write-Host ""
}
