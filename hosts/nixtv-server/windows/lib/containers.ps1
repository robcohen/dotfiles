# lib/containers.ps1 - Container management

function Get-PodmanComposeExecutable {
    $podmanCompose = Get-Command "podman-compose" -ErrorAction SilentlyContinue
    if ($podmanCompose) {
        return $podmanCompose.Source
    }

    $podmanComposePath = "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\Scripts\podman-compose.exe"
    if (Test-Path $podmanComposePath) {
        return $podmanComposePath
    }

    return $null
}

function Start-ContainerStack {
    param(
        [string]$ComposeFile,
        [switch]$Pull
    )

    Write-Log "Starting container stack..."

    # Ensure Podman machine is running
    if (-not (Start-PodmanMachine)) {
        Write-Log "  Cannot start containers - Podman machine not running" -Level Error
        return $false
    }

    $podmanCompose = Get-PodmanComposeExecutable
    if (-not $podmanCompose) {
        Write-Log "  podman-compose not found" -Level Error
        Write-Log "  Run: pip install podman-compose" -Level Info
        return $false
    }

    if (-not (Test-Path $ComposeFile)) {
        Write-Log "  Compose file not found: $ComposeFile" -Level Error
        return $false
    }

    $composeDir = Split-Path -Parent $ComposeFile

    try {
        Push-Location $composeDir

        if ($Pull) {
            Write-Log "  Pulling latest images..."
            & $podmanCompose pull 2>&1 | Out-Null
        }

        Write-Log "  Starting containers..."
        & $podmanCompose up -d 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "  Container stack started" -Level Success
            return $true
        } else {
            Write-Log "  Failed to start some containers" -Level Warning
            return $false
        }
    } catch {
        Write-Log "  Failed to start container stack: $_" -Level Error
        return $false
    } finally {
        Pop-Location
    }
}

function Stop-ContainerStack {
    param([string]$ComposeFile)

    Write-Log "Stopping container stack..."

    $podmanCompose = Get-PodmanComposeExecutable
    if (-not $podmanCompose) {
        Write-Log "  podman-compose not found" -Level Warning
        return
    }

    $composeDir = Split-Path -Parent $ComposeFile

    try {
        Push-Location $composeDir
        & $podmanCompose down 2>&1
        Write-Log "  Container stack stopped" -Level Success
    } catch {
        Write-Log "  Failed to stop container stack: $_" -Level Warning
    } finally {
        Pop-Location
    }
}

function Show-ContainerStatus {
    Write-Log "Container status:"

    $podman = Get-PodmanExecutable
    if (-not $podman) {
        Write-Log "  Podman not available" -Level Warning
        return
    }

    try {
        $containers = & $podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1
        foreach ($line in $containers) {
            Write-Log "  $line"
        }

        $running = (& $podman ps -q 2>&1 | Measure-Object).Count
        Write-Log "  Total running: $running" -Level Success
    } catch {
        Write-Log "  Failed to get container status: $_" -Level Warning
    }
}

function Update-Containers {
    param([string]$ComposeFile)

    Write-Log "Updating containers..."

    $podmanCompose = Get-PodmanComposeExecutable
    if (-not $podmanCompose) {
        Write-Log "  podman-compose not found" -Level Error
        return
    }

    $composeDir = Split-Path -Parent $ComposeFile

    try {
        Push-Location $composeDir

        Write-Log "  Pulling latest images..."
        & $podmanCompose pull 2>&1

        Write-Log "  Recreating containers with new images..."
        & $podmanCompose up -d --force-recreate 2>&1

        Write-Log "  Containers updated" -Level Success
    } catch {
        Write-Log "  Failed to update containers: $_" -Level Error
    } finally {
        Pop-Location
    }
}

function Get-ComposeFilePath {
    param($Config)

    return "$($Config.paths.appData)\Scripts\docker-compose.yml"
}

function Install-ComposeFile {
    param($Config)

    Write-Log "Installing docker-compose.yml..."

    $destPath = Get-ComposeFilePath -Config $Config
    $destDir = Split-Path -Parent $destPath

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Download from GitHub
    $repoUrl = "https://raw.githubusercontent.com/user/dotfiles/main/hosts/nixtv-server/windows/docker-compose.yml"

    try {
        Invoke-WebRequest -Uri $repoUrl -OutFile $destPath -UseBasicParsing
        Write-Log "  Downloaded docker-compose.yml" -Level Success
    } catch {
        Write-Log "  Failed to download compose file: $_" -Level Warning
        Write-Log "  Copy manually from dotfiles repo" -Level Info
    }
}
