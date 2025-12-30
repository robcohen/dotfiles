# lib/directories.ps1 - Directory structure creation

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
        "$($Config.paths.appData)\Prowlarr",
        "$($Config.paths.appData)\Radarr",
        "$($Config.paths.appData)\Sonarr",
        "$($Config.paths.appData)\Lidarr",
        "$($Config.paths.appData)\Readarr",
        "$($Config.paths.appData)\Bazarr",
        "$($Config.paths.appData)\qBittorrent",
        "$($Config.paths.appData)\Homarr\configs",
        "$($Config.paths.appData)\Homarr\icons",
        "$($Config.paths.appData)\Homarr\data",
        "$($Config.paths.appData)\Jellyseerr",
        "$($Config.paths.appData)\Recyclarr",
        "$($Config.paths.appData)\Tdarr\server",
        "$($Config.paths.appData)\Tdarr\configs",
        "$($Config.paths.appData)\Tdarr\logs",
        "$($Config.paths.appData)\Tdarr\transcode_cache",
        "$($Config.paths.appData)\UptimeKuma",
        "$($Config.paths.appData)\Scripts",
        "$($Config.paths.appData)\Tailscale",
        "$($Config.paths.vms)"
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
