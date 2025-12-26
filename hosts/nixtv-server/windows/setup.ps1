# hosts/nixtv-server/windows/setup.ps1
# Windows host setup for nixtv-server
#
# Run as Administrator:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\setup.ps1
#
# Options:
#   .\setup.ps1 -ConfigPath ".\custom-config.json"
#   .\setup.ps1 -SkipReboot
#   .\setup.ps1 -Phase 2  # Run specific phase after reboot
#   .\setup.ps1 -Verbose

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$ConfigPath = "$PSScriptRoot\config.json",
    [switch]$SkipReboot,
    [int]$Phase = 0
)

$ErrorActionPreference = "Stop"

# ===========================================================================
# IMPORT MODULES
# ===========================================================================
$libPath = Join-Path $PSScriptRoot "lib"

. "$libPath\common.ps1"
. "$libPath\checks.ps1"
. "$libPath\windows-features.ps1"
. "$libPath\packages.ps1"
. "$libPath\directories.ps1"
. "$libPath\firewall.ps1"
. "$libPath\tailscale.ps1"
. "$libPath\podman.ps1"
. "$libPath\port-forwarding.ps1"
. "$libPath\power.ps1"
. "$libPath\containers.ps1"
. "$libPath\vm.ps1"

# ===========================================================================
# SUMMARY
# ===========================================================================
function Show-Summary {
    param($Config)

    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "  SETUP COMPLETE" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Cyan

    Write-Host @"

Next steps:
"@

    if (Get-RebootRequired) {
        Write-Host "  0. REBOOT REQUIRED for Windows features" -ForegroundColor Red
        Write-Host "     After reboot, run: .\setup.ps1 -Phase 2" -ForegroundColor Yellow
    }

    Write-Host @"
  1. Log into Tailscale: tailscale login
  2. Add device to Mullvad in Tailscale admin console
  3. Connect to Mullvad: $($Config.paths.appData)\Tailscale\mullvad-connect.ps1 -Country us
  4. Check services: http://localhost:7575 (Homarr dashboard)

Tailscale helper scripts:
  - $($Config.paths.appData)\Tailscale\mullvad-connect.ps1
  - $($Config.paths.appData)\Tailscale\mullvad-disconnect.ps1
  - $($Config.paths.appData)\Tailscale\mullvad-status.ps1

Services available at:
  - Homarr:      http://localhost:7575  (Dashboard - start here!)
  - Jellyfin:    http://localhost:8096
  - Jellyseerr:  http://localhost:5055
  - Ollama:      http://localhost:11434
  - Open WebUI:  http://localhost:3000
  - Radarr:      http://localhost:7878
  - Sonarr:      http://localhost:8989
  - Prowlarr:    http://localhost:9696
  - Lidarr:      http://localhost:8686
  - Readarr:     http://localhost:8787
  - Bazarr:      http://localhost:6767
  - qBittorrent: http://localhost:8080
  - Tdarr:       http://localhost:8265
  - Uptime Kuma: http://localhost:3001

Logs saved to: $(Get-LogFile)
"@

    if (Get-RebootRequired -and -not $SkipReboot) {
        Write-Host "`nReboot now? (y/N): " -NoNewline -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq 'y') {
            Write-Log "Rebooting in 10 seconds..." -Level Warning
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }
    }
}

# ===========================================================================
# PHASE 1: Pre-reboot setup
# ===========================================================================
function Invoke-Phase1 {
    param($Config)

    Write-Host "`n[1/8] Pre-flight checks" -ForegroundColor Yellow

    # Extract drive letter from media path
    $driveLetter = $Config.paths.media.Substring(0, 1)
    if (-not (Test-DiskSpace -DriveLetter $driveLetter -RequiredGB $Config.requirements.minDiskSpaceGB)) {
        Write-Log "Insufficient disk space. Continuing anyway..." -Level Warning
    }

    $gpuAvailable = Test-NvidiaGpu
    if (-not $gpuAvailable) {
        Write-Log "NVIDIA GPU not detected - GPU features will not work" -Level Warning
        Write-Host "Continue anyway? (y/N): " -NoNewline
        $response = Read-Host
        if ($response -ne 'y') {
            exit 1
        }
    }

    # Enable Windows features
    Write-Host "`n[2/8] Windows features" -ForegroundColor Yellow
    Enable-WindowsFeatures

    # Install WSL2
    Write-Host "`n[3/8] WSL2 setup" -ForegroundColor Yellow
    Install-WSL2

    # Install packages
    Write-Host "`n[4/8] Installing packages" -ForegroundColor Yellow
    Install-Packages -Packages $Config.packages
    Install-PythonAndPodmanCompose

    # Create directories
    Write-Host "`n[5/8] Directory structure" -ForegroundColor Yellow
    New-DirectoryStructure -Config $Config

    # Configure firewall
    Write-Host "`n[6/8] Firewall rules" -ForegroundColor Yellow
    Set-FirewallRules -Services $Config.services
    Set-DnsLeakPreventionRules

    # Configure Tailscale
    Write-Host "`n[7/8] Tailscale configuration" -ForegroundColor Yellow
    Set-TailscaleConfiguration
    New-TailscaleHelperScripts -Config $Config

    # Configure power settings
    Write-Host "`n[8/8] Power settings" -ForegroundColor Yellow
    Set-PowerSettings
    Set-HighPerformancePowerPlan

    if (Get-RebootRequired) {
        Write-Log "Phase 1 complete. Reboot required before Phase 2." -Level Warning
    } else {
        Write-Log "Phase 1 complete. Proceeding to Phase 2..." -Level Success
        Invoke-Phase2 -Config $Config
    }
}

# ===========================================================================
# PHASE 2: Post-reboot setup
# ===========================================================================
function Invoke-Phase2 {
    param($Config)

    Write-Host "`n[1/5] Podman configuration" -ForegroundColor Yellow
    Set-PodmanConfiguration

    Write-Host "`n[2/5] Starting Podman machine" -ForegroundColor Yellow
    Start-PodmanMachine

    Write-Host "`n[3/5] Port forwarding" -ForegroundColor Yellow
    Set-PortForwarding -Services $Config.services

    Write-Host "`n[4/5] Starting containers" -ForegroundColor Yellow
    $composeFile = Get-ComposeFilePath -Config $Config
    if (Test-Path $composeFile) {
        Start-ContainerStack -ComposeFile $composeFile
    } else {
        Write-Log "docker-compose.yml not found at $composeFile" -Level Warning
        Write-Log "Copy it from the dotfiles repo or run Install-ComposeFile" -Level Info
    }

    Write-Host "`n[5/5] Verification" -ForegroundColor Yellow
    Test-Installation
    Show-ContainerStatus
}

# ===========================================================================
# MAIN
# ===========================================================================
function Main {
    Write-Host @"

    ███╗   ██╗██╗██╗  ██╗████████╗██╗   ██╗
    ████╗  ██║██║╚██╗██╔╝╚══██╔══╝██║   ██║
    ██╔██╗ ██║██║ ╚███╔╝    ██║   ██║   ██║
    ██║╚██╗██║██║ ██╔██╗    ██║   ╚██╗ ██╔╝
    ██║ ╚████║██║██╔╝ ██╗   ██║    ╚████╔╝
    ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝   ╚═╝     ╚═══╝
                Windows Setup Script

"@ -ForegroundColor Cyan

    Initialize-Logging

    Write-Log "Starting nixtv-server Windows setup..." -Level Info
    Write-Log "Config: $ConfigPath"

    # Load configuration
    $config = Get-Configuration -Path $ConfigPath

    switch ($Phase) {
        0 {
            # Full setup
            Invoke-Phase1 -Config $config
        }
        1 {
            # Phase 1 only
            Invoke-Phase1 -Config $config
        }
        2 {
            # Phase 2 only (post-reboot)
            Invoke-Phase2 -Config $config
        }
        default {
            Write-Log "Invalid phase: $Phase. Use 0 (full), 1, or 2." -Level Error
            exit 1
        }
    }

    # Summary
    Show-Summary -Config $config

    Stop-Transcript
}

# Run main
Main
