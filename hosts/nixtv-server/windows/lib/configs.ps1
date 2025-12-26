# lib/configs.ps1 - Deploy configuration files

function Install-ServiceConfigs {
    param($Config)

    Write-Log "Installing service configurations..."

    $scriptRoot = Get-ScriptRoot
    $configsDir = Join-Path $scriptRoot "configs"

    if (-not (Test-Path $configsDir)) {
        Write-Log "  No configs directory found at $configsDir" -Level Warning
        return
    }

    # Homarr config
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
            Write-Log "  Homarr restarted" -Level Success
        }
    }

    # Add more config deployments here as needed
}
