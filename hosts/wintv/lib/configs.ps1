# lib/configs.ps1 - Deploy configuration files

function Set-ArrUrlBase {
    param(
        [string]$ServiceName,
        [string]$UrlBase,
        [string]$ConfigPath
    )

    Write-Log "  Configuring $ServiceName URL base..."

    if (-not (Test-Path $ConfigPath)) {
        Write-Log "    Config not found at $ConfigPath - service may not have started yet" -Level Warning
        return $false
    }

    try {
        $content = Get-Content $ConfigPath -Raw

        if ($content -match "<UrlBase>$UrlBase</UrlBase>") {
            Write-Log "    URL base already set" -Level Success
            return $true
        }

        if ($content -match "<UrlBase></UrlBase>") {
            $content = $content -replace "<UrlBase></UrlBase>", "<UrlBase>$UrlBase</UrlBase>"
        } elseif ($content -match "<UrlBase>[^<]*</UrlBase>") {
            $content = $content -replace "<UrlBase>[^<]*</UrlBase>", "<UrlBase>$UrlBase</UrlBase>"
        } else {
            Write-Log "    Could not find UrlBase element in config" -Level Warning
            return $false
        }

        Set-Content -Path $ConfigPath -Value $content -NoNewline
        Write-Log "    URL base set to $UrlBase" -Level Success

        # Restart the service
        $running = podman ps --filter name=$ServiceName --format "{{.Names}}" 2>$null
        if ($running -eq $ServiceName) {
            Write-Log "    Restarting $ServiceName..."
            podman restart $ServiceName 2>&1 | Out-Null
        }

        return $true
    } catch {
        Write-Log "    Failed to configure $ServiceName : $_" -Level Error
        return $false
    }
}

function Set-JellyfinNetworkConfig {
    param($Config)

    Write-Log "  Configuring Jellyfin network settings..."

    $networkPath = "$($Config.paths.appData)\Jellyfin\config\network.xml"

    if (-not (Test-Path $networkPath)) {
        Write-Log "    Jellyfin network config not found - service may not have started yet" -Level Warning
        return $false
    }

    try {
        $content = Get-Content $networkPath -Raw

        # Set BaseUrl to /jellyfin
        if ($content -notmatch "<BaseUrl>/jellyfin</BaseUrl>") {
            if ($content -match "<BaseUrl>[^<]*</BaseUrl>") {
                $content = $content -replace "<BaseUrl>[^<]*</BaseUrl>", "<BaseUrl>/jellyfin</BaseUrl>"
            }
            Set-Content -Path $networkPath -Value $content -NoNewline
            Write-Log "    Jellyfin BaseUrl set to /jellyfin" -Level Success

            # Restart Jellyfin
            $running = podman ps --filter name=jellyfin --format "{{.Names}}" 2>$null
            if ($running -eq "jellyfin") {
                Write-Log "    Restarting Jellyfin..."
                podman restart jellyfin 2>&1 | Out-Null
            }
        } else {
            Write-Log "    Jellyfin BaseUrl already configured" -Level Success
        }

        return $true
    } catch {
        Write-Log "    Failed to configure Jellyfin: $_" -Level Error
        return $false
    }
}

function Install-ServiceConfigs {
    param($Config)

    Write-Log "Installing service configurations..."

    $scriptRoot = Get-ScriptRoot
    $configsDir = Join-Path $scriptRoot "configs"

    # Deploy Caddyfile
    $caddyfileSource = Join-Path $configsDir "Caddyfile"
    $caddyfileDest = "$($Config.paths.appData)\Caddy\Caddyfile"
    if (Test-Path $caddyfileSource) {
        $caddyDir = Split-Path $caddyfileDest -Parent
        if (-not (Test-Path $caddyDir)) {
            New-Item -ItemType Directory -Path $caddyDir -Force | Out-Null
            New-Item -ItemType Directory -Path "$caddyDir\data" -Force | Out-Null
            New-Item -ItemType Directory -Path "$caddyDir\config" -Force | Out-Null
        }
        Copy-Item $caddyfileSource $caddyfileDest -Force
        Write-Log "  Installed Caddyfile" -Level Success
    }

    # Homarr config
    if (Test-Path $configsDir) {
        $homarrConfig = Join-Path $configsDir "homarr-default.json"
        $homarrDest = "$($Config.paths.appData)\Homarr\configs\default.json"

        if (Test-Path $homarrConfig) {
            $destDir = Split-Path $homarrDest -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }

            Copy-Item $homarrConfig $homarrDest -Force
            Write-Log "  Installed Homarr config" -Level Success

            # Restart Homarr if running
            $homarr = podman ps --filter name=homarr --format "{{.Names}}" 2>$null
            if ($homarr -eq "homarr") {
                Write-Log "  Restarting Homarr to apply config..."
                podman restart homarr 2>&1 | Out-Null
            }
        }
    }

    # Configure URL bases for *arr apps (requires containers to have started once)
    Write-Log "Configuring URL bases for reverse proxy..."

    # *arr apps - all use config.xml
    $arrApps = @{
        "radarr"   = @{ UrlBase = "/radarr";   ConfigPath = "$($Config.paths.appData)\Radarr\config.xml" }
        "sonarr"   = @{ UrlBase = "/sonarr";   ConfigPath = "$($Config.paths.appData)\Sonarr\config.xml" }
        "prowlarr" = @{ UrlBase = "/prowlarr"; ConfigPath = "$($Config.paths.appData)\Prowlarr\config.xml" }
        "lidarr"   = @{ UrlBase = "/lidarr";   ConfigPath = "$($Config.paths.appData)\Lidarr\config.xml" }
        "readarr"  = @{ UrlBase = "/readarr";  ConfigPath = "$($Config.paths.appData)\Readarr\config.xml" }
        "bazarr"   = @{ UrlBase = "/bazarr";   ConfigPath = "$($Config.paths.appData)\Bazarr\config\config.yaml" }
    }

    foreach ($app in $arrApps.Keys) {
        $settings = $arrApps[$app]
        if ($app -eq "bazarr") {
            # Bazarr uses YAML config
            Set-BazarrUrlBase -Config $Config -UrlBase $settings.UrlBase
        } else {
            Set-ArrUrlBase -ServiceName $app -UrlBase $settings.UrlBase -ConfigPath $settings.ConfigPath
        }
    }

    # Jellyfin network config
    Set-JellyfinNetworkConfig -Config $Config
}

function Set-BazarrUrlBase {
    param($Config, [string]$UrlBase)

    Write-Log "  Configuring Bazarr URL base..."

    $configPath = "$($Config.paths.appData)\Bazarr\config\config.yaml"

    if (-not (Test-Path $configPath)) {
        Write-Log "    Bazarr config not found - service may not have started yet" -Level Warning
        return $false
    }

    try {
        $content = Get-Content $configPath -Raw

        # Bazarr uses base_url in YAML
        if ($content -match "base_url:\s*$UrlBase") {
            Write-Log "    URL base already set" -Level Success
            return $true
        }

        if ($content -match "base_url:\s*[^\n]*") {
            $content = $content -replace "base_url:\s*[^\n]*", "base_url: $UrlBase"
        } else {
            # Add base_url under general section
            $content = $content -replace "(general:)", "`$1`n  base_url: $UrlBase"
        }

        Set-Content -Path $configPath -Value $content -NoNewline
        Write-Log "    URL base set to $UrlBase" -Level Success

        # Restart Bazarr
        $running = podman ps --filter name=bazarr --format "{{.Names}}" 2>$null
        if ($running -eq "bazarr") {
            Write-Log "    Restarting Bazarr..."
            podman restart bazarr 2>&1 | Out-Null
        }

        return $true
    } catch {
        Write-Log "    Failed to configure Bazarr: $_" -Level Error
        return $false
    }
}
