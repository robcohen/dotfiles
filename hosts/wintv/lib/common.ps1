# lib/common.ps1 - Common utilities for wintv setup scripts

$Script:LogDir = "$env:LOCALAPPDATA\wintv-setup"
$Script:LogFile = "$Script:LogDir\setup-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"
$Script:RebootRequired = $false

function Initialize-Logging {
    if (-not (Test-Path $Script:LogDir)) {
        New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
    }
    Start-Transcript -Path $Script:LogFile -Append
    Write-Host "Logging to: $Script:LogFile" -ForegroundColor Gray
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

function Get-Configuration {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Log "Config file not found: $Path" -Level Error
        Write-Log "Creating default config..." -Level Warning

        $defaultConfig = @{
            paths = @{
                media = "C:\Media"
                appData = "C:\ProgramData\wintv"
                vms = "C:\VMs"
            }
            podman = @{
                cpus = 8
                memoryGB = 16
                diskGB = 100
            }
            packages = @(
                "RedHat.Podman-Desktop"
                "Microsoft.PowerShell"
                "Microsoft.WindowsTerminal"
                "Git.Git"
                "Microsoft.Office"
                "Tailscale.Tailscale"
                "Python.Python.3.12"
            )
            services = @{
                jellyfin = @{ port = 8096; protocol = "TCP" }
                jellyseerr = @{ port = 5055; protocol = "TCP" }
                ollama = @{ port = 11434; protocol = "TCP" }
                openWebUI = @{ port = 3000; protocol = "TCP" }
                radarr = @{ port = 7878; protocol = "TCP" }
                sonarr = @{ port = 8989; protocol = "TCP" }
                prowlarr = @{ port = 9696; protocol = "TCP" }
                lidarr = @{ port = 8686; protocol = "TCP" }
                readarr = @{ port = 8787; protocol = "TCP" }
                bazarr = @{ port = 6767; protocol = "TCP" }
                qbittorrent = @{ port = 8080; protocol = "TCP" }
                tdarr = @{ port = 8265; protocol = "TCP" }
                flaresolverr = @{ port = 8191; protocol = "TCP" }
                uptimekuma = @{ port = 3001; protocol = "TCP" }
            }
            requirements = @{
                minDiskSpaceGB = 200
            }
        }

        $defaultConfig | ConvertTo-Json -Depth 4 | Out-File $Path -Encoding UTF8
    }

    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Set-RebootRequired {
    $Script:RebootRequired = $true
}

function Get-RebootRequired {
    return $Script:RebootRequired
}

function Get-ScriptRoot {
    return $PSScriptRoot | Split-Path -Parent
}

function Get-LogFile {
    return $Script:LogFile
}

# ===========================================================================
# API Key Generation
# ===========================================================================

function Get-DerivedApiKey {
    <#
    .SYNOPSIS
        Generates a deterministic API key from a base password and service name.

    .DESCRIPTION
        Uses SHA256 to derive a 32-character hex API key that is:
        - Deterministic (same inputs = same output)
        - Unique per service
        - Suitable for arr stack services

    .PARAMETER ServiceName
        The name of the service (e.g., "prowlarr", "radarr")

    .EXAMPLE
        $key = Get-DerivedApiKey -ServiceName "prowlarr"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )

    if (-not $env:ADMIN_PASSWORD) {
        throw "ADMIN_PASSWORD environment variable is not set. Source your .env file first."
    }

    $input = "$env:ADMIN_PASSWORD-$ServiceName"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($input)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [BitConverter]::ToString($hash).Replace("-","").Substring(0,32).ToLower()
}

function Get-AllApiKeys {
    <#
    .SYNOPSIS
        Returns a hashtable of all derived API keys for arr stack services.
    #>
    return @{
        Prowlarr = Get-DerivedApiKey "prowlarr"
        Radarr = Get-DerivedApiKey "radarr"
        Sonarr = Get-DerivedApiKey "sonarr"
        Lidarr = Get-DerivedApiKey "lidarr"
        Readarr = Get-DerivedApiKey "readarr"
        Bazarr = Get-DerivedApiKey "bazarr"
        Jellyfin = Get-DerivedApiKey "jellyfin"
    }
}
