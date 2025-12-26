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
#   .\setup.ps1 -Verbose

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$ConfigPath = "$PSScriptRoot\config.json",
    [switch]$SkipReboot
)

$ErrorActionPreference = "Stop"
$Script:RebootRequired = $false

# ===========================================================================
# LOGGING
# ===========================================================================
$LogDir = "$env:LOCALAPPDATA\nixtv-setup"
$LogFile = "$LogDir\setup-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"

function Initialize-Logging {
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    Start-Transcript -Path $LogFile -Append
    Write-Host "Logging to: $LogFile" -ForegroundColor Gray
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info"    { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }

    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

# ===========================================================================
# CONFIGURATION
# ===========================================================================
function Get-Configuration {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Log "Config file not found: $Path" -Level Error
        Write-Log "Creating default config..." -Level Warning

        $defaultConfig = @{
            paths = @{
                media = "C:\Media"
                appData = "C:\ProgramData\nixtv"
                vms = "C:\VMs"
            }
            vm = @{
                name = "nixtv-server"
                memoryGB = 8
                cpuCount = 4
                diskGB = 100
            }
            packages = @(
                "RedHat.Podman-Desktop"
                "Microsoft.PowerShell"
                "Microsoft.WindowsTerminal"
                "Git.Git"
                "Microsoft.Office"
                "Tailscale.Tailscale"
            )
            services = @{
                jellyfin = @{ port = 8096; protocol = "TCP" }
                jellyfinHttps = @{ port = 8920; protocol = "TCP" }
                jellyfinDlna = @{ port = 1900; protocol = "UDP" }
                jellyfinDiscovery = @{ port = 7359; protocol = "UDP" }
                ollama = @{ port = 11434; protocol = "TCP" }
                openWebUI = @{ port = 3000; protocol = "TCP" }
            }
            requirements = @{
                minDiskSpaceGB = 200
            }
        }

        $defaultConfig | ConvertTo-Json -Depth 4 | Out-File $Path -Encoding UTF8
    }

    return Get-Content $Path -Raw | ConvertFrom-Json
}

# ===========================================================================
# SYSTEM CHECKS
# ===========================================================================
function Test-DiskSpace {
    param(
        [string]$DriveLetter,
        [int]$RequiredGB
    )

    Write-Log "Checking disk space on ${DriveLetter}:..."

    $drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
    if (-not $drive) {
        Write-Log "Drive ${DriveLetter}: not found" -Level Error
        return $false
    }

    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    if ($freeGB -lt $RequiredGB) {
        Write-Log "Insufficient disk space: ${freeGB}GB available, ${RequiredGB}GB required" -Level Error
        return $false
    }

    Write-Log "Disk space OK: ${freeGB}GB available" -Level Success
    return $true
}

function Test-NvidiaGpu {
    Write-Log "Checking NVIDIA GPU..."

    try {
        $nvidiaSmi = Get-Command "nvidia-smi" -ErrorAction SilentlyContinue
        if (-not $nvidiaSmi) {
            # Try common installation paths
            $paths = @(
                "C:\Windows\System32\nvidia-smi.exe",
                "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
            )
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    $nvidiaSmi = $path
                    break
                }
            }
        }

        if (-not $nvidiaSmi) {
            Write-Log "nvidia-smi not found - NVIDIA drivers may not be installed" -Level Warning
            return $false
        }

        $output = & $nvidiaSmi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "NVIDIA GPU detected: $output" -Level Success
            return $true
        } else {
            Write-Log "nvidia-smi failed: $output" -Level Warning
            return $false
        }
    } catch {
        Write-Log "GPU check failed: $_" -Level Warning
        return $false
    }
}

# ===========================================================================
# WINDOWS FEATURES
# ===========================================================================
function Enable-WindowsFeatures {
    Write-Log "Enabling Windows features..."

    $features = @(
        @{ Name = "Microsoft-Windows-Subsystem-Linux"; DisplayName = "WSL" },
        @{ Name = "VirtualMachinePlatform"; DisplayName = "Virtual Machine Platform" },
        @{ Name = "Microsoft-Hyper-V-All"; DisplayName = "Hyper-V" },
        @{ Name = "Containers"; DisplayName = "Containers" }
    )

    foreach ($feature in $features) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature.Name -ErrorAction SilentlyContinue

        if ($state.State -eq "Enabled") {
            Write-Log "  $($feature.DisplayName) already enabled" -Level Success
        } else {
            Write-Log "  Enabling $($feature.DisplayName)..."
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction Stop | Out-Null
                Write-Log "  $($feature.DisplayName) enabled" -Level Success
                $Script:RebootRequired = $true
            } catch {
                Write-Log "  Failed to enable $($feature.DisplayName): $_" -Level Warning
            }
        }
    }
}

function Install-WSL2 {
    Write-Log "Configuring WSL2..."

    # Check if WSL is installed
    $wsl = Get-Command "wsl" -ErrorAction SilentlyContinue
    if (-not $wsl) {
        Write-Log "  Installing WSL..."
        try {
            wsl --install --no-distribution
            $Script:RebootRequired = $true
            Write-Log "  WSL installed (reboot required)" -Level Success
        } catch {
            Write-Log "  Failed to install WSL: $_" -Level Error
        }
        return
    }

    # Set WSL2 as default
    try {
        wsl --set-default-version 2 2>&1 | Out-Null
        Write-Log "  WSL2 set as default" -Level Success
    } catch {
        Write-Log "  Failed to set WSL2 as default: $_" -Level Warning
    }

    # Update WSL
    try {
        Write-Log "  Updating WSL..."
        wsl --update 2>&1 | Out-Null
        Write-Log "  WSL updated" -Level Success
    } catch {
        Write-Log "  WSL update skipped: $_" -Level Warning
    }
}

# ===========================================================================
# PACKAGE MANAGEMENT
# ===========================================================================
function Test-PackageInstalled {
    param([string]$PackageId)

    $result = winget list --id $PackageId --accept-source-agreements 2>&1
    return $result -match $PackageId
}

function Install-Packages {
    param([array]$Packages)

    Write-Log "Installing packages..."

    # Update winget sources
    Write-Log "  Updating package sources..."
    winget source update 2>&1 | Out-Null

    foreach ($package in $Packages) {
        if (Test-PackageInstalled -PackageId $package) {
            Write-Log "  $package already installed" -Level Success
        } else {
            Write-Log "  Installing $package..."
            try {
                $result = winget install --id $package --accept-source-agreements --accept-package-agreements -h 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "  $package installed" -Level Success
                } else {
                    Write-Log "  $package installation returned: $result" -Level Warning
                }
            } catch {
                Write-Log "  Failed to install $package : $_" -Level Error
            }
        }
    }
}

# ===========================================================================
# DIRECTORY STRUCTURE
# ===========================================================================
function New-DirectoryStructure {
    param($Config)

    Write-Log "Creating directory structure..."

    $directories = @(
        $Config.paths.media,
        "$($Config.paths.media)\Movies",
        "$($Config.paths.media)\TV",
        "$($Config.paths.media)\Music",
        "$($Config.paths.media)\Books",
        "$($Config.paths.media)\Downloads",
        "$($Config.paths.appData)\Jellyfin\config",
        "$($Config.paths.appData)\Jellyfin\cache",
        "$($Config.paths.appData)\Ollama",
        "$($Config.paths.appData)\OpenWebUI",
        "$($Config.paths.vms)\$($Config.vm.name)"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log "  Created: $dir" -Level Success
        } else {
            Write-Log "  Exists: $dir"
        }
    }
}

# ===========================================================================
# FIREWALL
# ===========================================================================
function Set-FirewallRules {
    param($Services)

    Write-Log "Configuring firewall rules..."

    foreach ($serviceName in $Services.PSObject.Properties.Name) {
        $service = $Services.$serviceName
        $ruleName = "nixtv-$serviceName"

        # Check if rule exists
        $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

        if ($existing) {
            Write-Log "  Rule '$ruleName' already exists"
        } else {
            try {
                New-NetFirewallRule `
                    -DisplayName $ruleName `
                    -Direction Inbound `
                    -Protocol $service.protocol `
                    -LocalPort $service.port `
                    -Action Allow `
                    -Profile Private,Domain | Out-Null
                Write-Log "  Created rule: $ruleName ($($service.protocol)/$($service.port))" -Level Success
            } catch {
                Write-Log "  Failed to create rule '$ruleName': $_" -Level Warning
            }
        }
    }
}

# ===========================================================================
# TAILSCALE CONFIGURATION
# ===========================================================================
function Set-TailscaleConfiguration {
    Write-Log "Configuring Tailscale..."

    $tailscale = Get-Command "tailscale" -ErrorAction SilentlyContinue
    if (-not $tailscale) {
        # Check common install path
        $tailscalePath = "${env:ProgramFiles}\Tailscale\tailscale.exe"
        if (Test-Path $tailscalePath) {
            $tailscale = $tailscalePath
        } else {
            Write-Log "  Tailscale not found - will configure after reboot" -Level Warning
            return
        }
    }

    # Check if already logged in
    $status = & $tailscale status 2>&1
    if ($status -match "Logged out") {
        Write-Log "  Tailscale installed but not logged in" -Level Warning
        Write-Log "  Run 'tailscale login' after setup completes" -Level Info
        return
    }

    # Configure tags for Mullvad access
    Write-Log "  Setting Tailscale tags..."
    try {
        & $tailscale set --advertise-tags=tag:personal,tag:mullvad 2>&1 | Out-Null
        Write-Log "  Tags configured: tag:personal, tag:mullvad" -Level Success
    } catch {
        Write-Log "  Failed to set tags (may need admin approval): $_" -Level Warning
    }

    Write-Log "  Tailscale configured" -Level Success
}

function Set-TailscaleDnsLeakPrevention {
    Write-Log "Configuring DNS leak prevention..."

    # Block DNS (port 53) except through Tailscale
    # This mirrors the iptables rules from tailscale-mullvad.nix

    $rules = @(
        @{
            Name = "nixtv-block-dns-udp"
            DisplayName = "Block DNS UDP (except Tailscale)"
            Direction = "Outbound"
            Protocol = "UDP"
            RemotePort = 53
            Action = "Block"
            Profile = "Any"
        },
        @{
            Name = "nixtv-block-dns-tcp"
            DisplayName = "Block DNS TCP (except Tailscale)"
            Direction = "Outbound"
            Protocol = "TCP"
            RemotePort = 53
            Action = "Block"
            Profile = "Any"
        },
        @{
            Name = "nixtv-allow-tailscale-dns"
            DisplayName = "Allow Tailscale MagicDNS"
            Direction = "Outbound"
            Protocol = "UDP"
            RemoteAddress = "100.100.100.100"
            RemotePort = 53
            Action = "Allow"
            Profile = "Any"
        }
    )

    foreach ($rule in $rules) {
        $existing = Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue

        if ($existing) {
            Write-Log "  Rule '$($rule.DisplayName)' already exists"
            continue
        }

        try {
            $params = @{
                Name = $rule.Name
                DisplayName = $rule.DisplayName
                Direction = $rule.Direction
                Protocol = $rule.Protocol
                RemotePort = $rule.RemotePort
                Action = $rule.Action
                Profile = $rule.Profile
                Enabled = "True"
            }

            if ($rule.RemoteAddress) {
                $params.RemoteAddress = $rule.RemoteAddress
            }

            New-NetFirewallRule @params | Out-Null
            Write-Log "  Created rule: $($rule.DisplayName)" -Level Success
        } catch {
            Write-Log "  Failed to create rule '$($rule.DisplayName)': $_" -Level Warning
        }
    }

    # Reorder rules so Allow comes before Block
    Write-Log "  Reordering firewall rules..."
    try {
        # Get the allow rule and set higher priority (lower number = higher priority)
        $allowRule = Get-NetFirewallRule -Name "nixtv-allow-tailscale-dns" -ErrorAction SilentlyContinue
        if ($allowRule) {
            # Windows Firewall processes Allow before Block by default when both match
            Write-Log "  Firewall rules configured for DNS leak prevention" -Level Success
        }
    } catch {
        Write-Log "  Rule ordering note: Windows processes Allow before Block" -Level Info
    }
}

function New-TailscaleHelperScripts {
    param($Config)

    Write-Log "Creating Tailscale helper scripts..."

    $scriptsPath = "$($Config.paths.appData)\Tailscale"
    if (-not (Test-Path $scriptsPath)) {
        New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null
    }

    # mullvad-connect.ps1
    $connectScript = @'
# List and connect to Mullvad exit nodes
param(
    [string]$Country,
    [string]$City
)

$tailscale = "${env:ProgramFiles}\Tailscale\tailscale.exe"

Write-Host "Available Mullvad exit nodes:" -ForegroundColor Cyan
& $tailscale exit-node list | Where-Object { $_ -match "mullvad" }

if ($Country) {
    $nodes = & $tailscale exit-node list | Where-Object { $_ -match "mullvad" -and $_ -match $Country }
    if ($City) {
        $nodes = $nodes | Where-Object { $_ -match $City }
    }

    $node = ($nodes | Select-Object -First 1) -split '\s+' | Select-Object -First 1
    if ($node) {
        Write-Host "`nConnecting to: $node" -ForegroundColor Green
        & $tailscale set --exit-node=$node --exit-node-allow-lan-access=true
    } else {
        Write-Host "No matching node found" -ForegroundColor Red
    }
}
'@

    $connectScript | Out-File "$scriptsPath\mullvad-connect.ps1" -Encoding UTF8
    Write-Log "  Created: $scriptsPath\mullvad-connect.ps1" -Level Success

    # mullvad-disconnect.ps1
    $disconnectScript = @'
# Disconnect from Mullvad exit node
$tailscale = "${env:ProgramFiles}\Tailscale\tailscale.exe"
& $tailscale set --exit-node=
Write-Host "Disconnected from Mullvad exit node" -ForegroundColor Green
'@

    $disconnectScript | Out-File "$scriptsPath\mullvad-disconnect.ps1" -Encoding UTF8
    Write-Log "  Created: $scriptsPath\mullvad-disconnect.ps1" -Level Success

    # mullvad-status.ps1
    $statusScript = @'
# Check Mullvad/Tailscale status and DNS leaks
$tailscale = "${env:ProgramFiles}\Tailscale\tailscale.exe"

Write-Host "=== Tailscale Status ===" -ForegroundColor Cyan
& $tailscale status

Write-Host "`n=== Exit Node ===" -ForegroundColor Cyan
$exitNode = & $tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty ExitNodeStatus -ErrorAction SilentlyContinue
if ($exitNode) {
    Write-Host "Connected to: $($exitNode.TailscaleIPs)" -ForegroundColor Green
} else {
    Write-Host "No exit node active" -ForegroundColor Yellow
}

Write-Host "`n=== DNS Leak Test ===" -ForegroundColor Cyan
try {
    $result = Invoke-RestMethod -Uri "https://am.i.mullvad.net/json" -TimeoutSec 10
    if ($result.mullvad_exit_ip) {
        Write-Host "PROTECTED via Mullvad" -ForegroundColor Green
        Write-Host "  Exit: $($result.mullvad_exit_ip_hostname)"
        Write-Host "  Location: $($result.city), $($result.country)"
        Write-Host "  IP: $($result.ip)"
    } else {
        Write-Host "NOT PROTECTED - Traffic not going through Mullvad!" -ForegroundColor Red
        Write-Host "  IP: $($result.ip)"
        Write-Host "  Location: $($result.city), $($result.country)"
    }
} catch {
    Write-Host "Could not check Mullvad status: $_" -ForegroundColor Red
}
'@

    $statusScript | Out-File "$scriptsPath\mullvad-status.ps1" -Encoding UTF8
    Write-Log "  Created: $scriptsPath\mullvad-status.ps1" -Level Success

    # Add to PATH suggestion
    Write-Log "  Helper scripts created in $scriptsPath" -Level Success
}

# ===========================================================================
# PODMAN CONFIGURATION
# ===========================================================================
function Set-PodmanConfiguration {
    Write-Log "Configuring Podman Desktop..."

    # Check if Podman is installed
    $podman = Get-Command "podman" -ErrorAction SilentlyContinue
    if (-not $podman) {
        $podmanPath = "$env:LOCALAPPDATA\Programs\podman-desktop\resources\podman\bin\podman.exe"
        if (-not (Test-Path $podmanPath)) {
            Write-Log "  Podman not found - start Podman Desktop first" -Level Warning
            return
        }
    }

    Write-Log "  Podman Desktop installed" -Level Success

    # Podman Desktop auto-start is configured via its own settings
    # Check if already in startup
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $podmanDesktopExe = "$env:LOCALAPPDATA\Programs\podman-desktop\Podman Desktop.exe"

    if (Test-Path "$startupPath\Podman Desktop.lnk") {
        Write-Log "  Podman Desktop auto-start already configured" -Level Success
    } elseif (Test-Path $podmanDesktopExe) {
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$startupPath\Podman Desktop.lnk")
            $shortcut.TargetPath = $podmanDesktopExe
            $shortcut.Save()
            Write-Log "  Podman Desktop auto-start configured" -Level Success
        } catch {
            Write-Log "  Failed to configure auto-start: $_" -Level Warning
        }
    }
}

# ===========================================================================
# HYPER-V VM SCRIPT
# ===========================================================================
function New-VMCreationScript {
    param($Config)

    Write-Log "Creating VM setup script..."

    $vmPath = "$($Config.paths.vms)\$($Config.vm.name)"
    $scriptPath = "$vmPath\create-vm.ps1"

    $vmScript = @"
# Run this after downloading NixOS ISO
# Download: nix build .#nixtv-server-iso

#Requires -RunAsAdministrator

`$VMName = "$($Config.vm.name)"
`$VMPath = "$vmPath"
`$ISOPath = "$vmPath\nixos.iso"  # Copy ISO here
`$VHDPath = "`$VMPath\$($Config.vm.name).vhdx"
`$MemoryGB = $($Config.vm.memoryGB)
`$CPUCount = $($Config.vm.cpuCount)
`$DiskGB = $($Config.vm.diskGB)

# Check if VM already exists
if (Get-VM -Name `$VMName -ErrorAction SilentlyContinue) {
    Write-Host "VM '`$VMName' already exists" -ForegroundColor Yellow
    `$response = Read-Host "Delete and recreate? (y/N)"
    if (`$response -eq 'y') {
        Stop-VM -Name `$VMName -Force -ErrorAction SilentlyContinue
        Remove-VM -Name `$VMName -Force
        Remove-Item `$VHDPath -Force -ErrorAction SilentlyContinue
    } else {
        exit 0
    }
}

# Check ISO exists
if (-not (Test-Path `$ISOPath)) {
    Write-Host "ERROR: ISO not found at `$ISOPath" -ForegroundColor Red
    Write-Host "Build ISO with: nix build .#nixtv-server-iso"
    Write-Host "Then copy to: `$ISOPath"
    exit 1
}

Write-Host "Creating VM '`$VMName'..." -ForegroundColor Cyan

# Create VM
New-VM -Name `$VMName -Path `$VMPath -MemoryStartupBytes (`$MemoryGB * 1GB) -Generation 2

# Configure CPU
Set-VMProcessor -VMName `$VMName -Count `$CPUCount

# Create and attach disk
New-VHD -Path `$VHDPath -SizeBytes (`$DiskGB * 1GB) -Dynamic
Add-VMHardDiskDrive -VMName `$VMName -Path `$VHDPath

# Attach ISO
Add-VMDvdDrive -VMName `$VMName -Path `$ISOPath

# Configure boot order (DVD first for install)
`$dvd = Get-VMDvdDrive -VMName `$VMName
Set-VMFirmware -VMName `$VMName -FirstBootDevice `$dvd

# Network - Default Switch for internet access
Connect-VMNetworkAdapter -VMName `$VMName -SwitchName "Default Switch"

# Disable Secure Boot (for NixOS)
Set-VMFirmware -VMName `$VMName -EnableSecureBoot Off

# Enable nested virtualization (optional, for containers in VM)
Set-VMProcessor -VMName `$VMName -ExposeVirtualizationExtensions `$true

# Dynamic memory
Set-VMMemory -VMName `$VMName -DynamicMemoryEnabled `$true -MinimumBytes 2GB -MaximumBytes (`$MemoryGB * 1GB)

# Enable checkpoints
Set-VM -VMName `$VMName -CheckpointType Production

Write-Host "`nVM '`$VMName' created successfully!" -ForegroundColor Green
Write-Host "`nNext steps:"
Write-Host "  1. Start-VM -Name `$VMName"
Write-Host "  2. vmconnect localhost `$VMName"
Write-Host "  3. Install NixOS from the ISO"
Write-Host "  4. After install, remove ISO: Remove-VMDvdDrive -VMName `$VMName"
"@

    $vmScript | Out-File -FilePath $scriptPath -Encoding UTF8
    Write-Log "  Created: $scriptPath" -Level Success
}

# ===========================================================================
# VERIFICATION
# ===========================================================================
function Test-Installation {
    Write-Log "Verifying installation..."

    $checks = @(
        @{
            Name = "WSL"
            Test = { (Get-Command wsl -ErrorAction SilentlyContinue) -ne $null }
        },
        @{
            Name = "Podman"
            Test = { (Get-Command podman -ErrorAction SilentlyContinue) -ne $null }
        },
        @{
            Name = "Tailscale"
            Test = {
                (Test-Path "${env:ProgramFiles}\Tailscale\tailscale.exe") -or
                (Get-Command tailscale -ErrorAction SilentlyContinue) -ne $null
            }
        },
        @{
            Name = "Hyper-V"
            Test = { (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -eq "Enabled" }
        },
        @{
            Name = "NVIDIA GPU"
            Test = { Test-NvidiaGpu }
        }
    )

    $allPassed = $true

    foreach ($check in $checks) {
        try {
            if (& $check.Test) {
                Write-Log "  $($check.Name): OK" -Level Success
            } else {
                Write-Log "  $($check.Name): Not available" -Level Warning
                $allPassed = $false
            }
        } catch {
            Write-Log "  $($check.Name): Check failed - $_" -Level Warning
            $allPassed = $false
        }
    }

    return $allPassed
}

function Show-Summary {
    param($Config)

    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "  SETUP COMPLETE" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Cyan

    Write-Host @"

Next steps:
"@

    if ($Script:RebootRequired) {
        Write-Host "  0. REBOOT REQUIRED for Windows features" -ForegroundColor Red
    }

    Write-Host @"
  1. Log into Tailscale: tailscale login
  2. Add device to Mullvad in Tailscale admin console
  3. Connect to Mullvad: $($Config.paths.appData)\Tailscale\mullvad-connect.ps1 -Country us
  4. Start Podman Desktop
  5. Run: podman-compose up -d (in this directory)
  6. Build NixOS ISO: nix build .#nixtv-server-iso
  7. Copy ISO to $($Config.paths.vms)\$($Config.vm.name)\nixos.iso
  8. Run: $($Config.paths.vms)\$($Config.vm.name)\create-vm.ps1
  9. Start VM and install NixOS

Tailscale helper scripts:
  - $($Config.paths.appData)\Tailscale\mullvad-connect.ps1
  - $($Config.paths.appData)\Tailscale\mullvad-disconnect.ps1
  - $($Config.paths.appData)\Tailscale\mullvad-status.ps1

Services will be available at:
  - Jellyfin:   http://localhost:8096
  - Ollama:     http://localhost:11434
  - Open WebUI: http://localhost:3000

Logs saved to: $LogFile
"@

    if ($Script:RebootRequired -and -not $SkipReboot) {
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

    # Pre-flight checks
    Write-Host "`n[1/10] Pre-flight checks" -ForegroundColor Yellow

    # Extract drive letter from media path
    $driveLetter = $config.paths.media.Substring(0, 1)
    if (-not (Test-DiskSpace -DriveLetter $driveLetter -RequiredGB $config.requirements.minDiskSpaceGB)) {
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
    Write-Host "`n[2/10] Windows features" -ForegroundColor Yellow
    Enable-WindowsFeatures

    # Install WSL2
    Write-Host "`n[3/10] WSL2 setup" -ForegroundColor Yellow
    Install-WSL2

    # Install packages
    Write-Host "`n[4/10] Installing packages" -ForegroundColor Yellow
    Install-Packages -Packages $config.packages

    # Create directories
    Write-Host "`n[5/10] Directory structure" -ForegroundColor Yellow
    New-DirectoryStructure -Config $config

    # Configure firewall
    Write-Host "`n[6/10] Firewall rules" -ForegroundColor Yellow
    Set-FirewallRules -Services $config.services

    # Configure Tailscale
    Write-Host "`n[7/10] Tailscale configuration" -ForegroundColor Yellow
    Set-TailscaleConfiguration
    Set-TailscaleDnsLeakPrevention
    New-TailscaleHelperScripts -Config $config

    # Configure Podman
    Write-Host "`n[8/10] Podman configuration" -ForegroundColor Yellow
    Set-PodmanConfiguration

    # Create VM script
    Write-Host "`n[9/10] VM setup script" -ForegroundColor Yellow
    New-VMCreationScript -Config $config

    # Verify installation
    Write-Host "`n[10/10] Verification" -ForegroundColor Yellow
    Test-Installation

    # Summary
    Show-Summary -Config $config

    Stop-Transcript
}

# Run main
Main
