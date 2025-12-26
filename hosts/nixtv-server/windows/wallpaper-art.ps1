# wallpaper-art.ps1
# Downloads random high-res art from Art Institute of Chicago and sets as wallpaper
#
# Usage:
#   .\wallpaper-art.ps1              # Download and set random artwork
#   .\wallpaper-art.ps1 -Install     # Install as startup task
#   .\wallpaper-art.ps1 -Uninstall   # Remove startup task

param(
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Configuration
$Config = @{
    # Art Institute of Chicago department IDs
    Departments = @("PC-10", "PC-838")  # European Paintings, Modern Art

    # Minimum image dimensions (for quality)
    MinWidth = 1920
    MinHeight = 1080

    # Prefer landscape orientation for better wallpaper fit
    PreferLandscape = $true

    # Where to save wallpapers
    WallpaperDir = "$env:LOCALAPPDATA\ArtWallpaper"

    # Keep history of recent wallpapers (avoid repeats)
    HistoryFile = "$env:LOCALAPPDATA\ArtWallpaper\history.json"
    HistorySize = 50

    # Wallpaper style: Fill (10), Fit (6), Stretch (2), Center (0), Span (22)
    WallpaperStyle = 10  # Fill - maintains aspect ratio, crops to fill
}

# Windows API for setting wallpaper
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);

    public const int SPI_SETDESKWALLPAPER = 0x0014;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDCHANGE = 0x02;
}
"@

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Get-ArtworkHistory {
    if (Test-Path $Config.HistoryFile) {
        return Get-Content $Config.HistoryFile -Raw | ConvertFrom-Json
    }
    return @()
}

function Add-ToHistory {
    param([int]$ArtworkId)
    $history = @(Get-ArtworkHistory)
    $history = @($ArtworkId) + $history | Select-Object -First $Config.HistorySize
    $history | ConvertTo-Json | Out-File $Config.HistoryFile -Encoding UTF8
}

function Get-RandomArtwork {
    Write-Log "Searching for artwork..."

    $history = Get-ArtworkHistory
    $department = $Config.Departments | Get-Random

    # Query for artworks with images, in selected department, public domain
    $query = @{
        "query" = @{
            "bool" = @{
                "must" = @(
                    @{ "term" = @{ "department_id" = $department } }
                    @{ "term" = @{ "is_public_domain" = $true } }
                    @{ "exists" = @{ "field" = "image_id" } }
                    @{ "range" = @{ "thumbnail.width" = @{ "gte" = $Config.MinWidth } } }
                )
            }
        }
        "fields" = @("id", "title", "artist_title", "image_id", "thumbnail", "department_title")
        "limit" = 100
    }

    $body = $query | ConvertTo-Json -Depth 10
    $response = Invoke-RestMethod -Uri "https://api.artic.edu/api/v1/artworks/search" `
        -Method Post -Body $body -ContentType "application/json"

    if ($response.data.Count -eq 0) {
        throw "No artworks found matching criteria"
    }

    # Filter out recently shown and prefer landscape
    $candidates = $response.data | Where-Object {
        $_.id -notin $history
    }

    if ($Config.PreferLandscape) {
        $landscape = $candidates | Where-Object {
            $_.thumbnail.width -gt $_.thumbnail.height
        }
        if ($landscape.Count -gt 0) {
            $candidates = $landscape
        }
    }

    if ($candidates.Count -eq 0) {
        $candidates = $response.data  # Fall back to all if history excludes everything
    }

    $artwork = $candidates | Get-Random

    Write-Log "Selected: $($artwork.title) by $($artwork.artist_title)" -Level Success
    Write-Log "Department: $($artwork.department_title)"

    return $artwork
}

function Get-ArtworkImage {
    param($Artwork)

    # Art Institute of Chicago IIIF image URL
    # Format: {base}/{image_id}/full/{size}/0/default.jpg
    $baseUrl = "https://www.artic.edu/iiif/2"
    $imageId = $Artwork.image_id

    # Request high resolution (1920 width, proportional height)
    $imageUrl = "$baseUrl/$imageId/full/1920,/0/default.jpg"

    Write-Log "Downloading image..."

    # Ensure directory exists
    if (-not (Test-Path $Config.WallpaperDir)) {
        New-Item -ItemType Directory -Path $Config.WallpaperDir -Force | Out-Null
    }

    # Clean filename
    $safeTitle = ($Artwork.title -replace '[\\/:*?"<>|]', '_').Substring(0, [Math]::Min(50, $Artwork.title.Length))
    $filename = "$($Artwork.id)_$safeTitle.jpg"
    $filepath = Join-Path $Config.WallpaperDir $filename

    # Download
    Invoke-WebRequest -Uri $imageUrl -OutFile $filepath

    Write-Log "Saved to: $filepath" -Level Success

    return $filepath
}

function Set-Wallpaper {
    param([string]$Path)

    Write-Log "Setting wallpaper..."

    # Set wallpaper style in registry
    $regPath = "HKCU:\Control Panel\Desktop"

    switch ($Config.WallpaperStyle) {
        10 { # Fill
            Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 10
            Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0
        }
        6 { # Fit
            Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 6
            Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0
        }
        2 { # Stretch
            Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 2
            Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0
        }
        22 { # Span
            Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 22
            Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0
        }
        0 { # Center
            Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 0
            Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0
        }
    }

    # Apply wallpaper
    $result = [Wallpaper]::SystemParametersInfo(
        [Wallpaper]::SPI_SETDESKWALLPAPER,
        0,
        $Path,
        [Wallpaper]::SPIF_UPDATEINIFILE -bor [Wallpaper]::SPIF_SENDCHANGE
    )

    if ($result -eq 0) {
        throw "Failed to set wallpaper"
    }

    Write-Log "Wallpaper set successfully!" -Level Success
}

function Install-StartupTask {
    Write-Log "Installing startup task..."

    $scriptPath = $MyInvocation.PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }

    # Create a startup shortcut
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutPath = Join-Path $startupPath "ArtWallpaper.lnk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $shortcut.WorkingDirectory = Split-Path $scriptPath
    $shortcut.WindowStyle = 7  # Minimized
    $shortcut.Save()

    Write-Log "Startup task installed: $shortcutPath" -Level Success
    Write-Log "Wallpaper will change on each login"
}

function Uninstall-StartupTask {
    Write-Log "Removing startup task..."

    $shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ArtWallpaper.lnk"

    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Log "Startup task removed" -Level Success
    } else {
        Write-Log "No startup task found" -Level Warning
    }
}

function Invoke-CleanupOldWallpapers {
    # Keep only the 10 most recent wallpapers
    $files = Get-ChildItem $Config.WallpaperDir -Filter "*.jpg" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 10

    foreach ($file in $files) {
        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Main
function Main {
    if ($Install) {
        Install-StartupTask
        return
    }

    if ($Uninstall) {
        Uninstall-StartupTask
        return
    }

    try {
        # Small delay on startup to let network connect
        if (-not [Environment]::UserInteractive) {
            Start-Sleep -Seconds 10
        }

        $artwork = Get-RandomArtwork
        $imagePath = Get-ArtworkImage -Artwork $artwork
        Set-Wallpaper -Path $imagePath
        Add-ToHistory -ArtworkId $artwork.id
        Invoke-CleanupOldWallpapers

        # Save info about current wallpaper
        @{
            id = $artwork.id
            title = $artwork.title
            artist = $artwork.artist_title
            department = $artwork.department_title
            file = $imagePath
            date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        } | ConvertTo-Json | Out-File "$($Config.WallpaperDir)\current.json" -Encoding UTF8

    } catch {
        Write-Log "Error: $_" -Level Error
        exit 1
    }
}

Main
