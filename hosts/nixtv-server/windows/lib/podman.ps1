# lib/podman.ps1 - Podman Desktop configuration

function Get-PodmanExecutable {
    $podman = Get-Command "podman" -ErrorAction SilentlyContinue
    if ($podman) {
        return $podman.Source
    }

    $podmanPath = "$env:LOCALAPPDATA\Programs\podman-desktop\resources\podman\bin\podman.exe"
    if (Test-Path $podmanPath) {
        return $podmanPath
    }

    return $null
}

function Set-PodmanConfiguration {
    Write-Log "Configuring Podman Desktop..."

    $podman = Get-PodmanExecutable
    if (-not $podman) {
        Write-Log "  Podman not found - start Podman Desktop first" -Level Warning
        return
    }

    Write-Log "  Podman Desktop installed" -Level Success

    # Configure auto-start
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

function Start-PodmanMachine {
    Write-Log "Starting Podman machine..."

    $podman = Get-PodmanExecutable
    if (-not $podman) {
        Write-Log "  Podman not found" -Level Warning
        return $false
    }

    # Check if machine is running
    $status = & $podman machine list --format "{{.Running}}" 2>&1
    if ($status -eq "true") {
        Write-Log "  Podman machine already running" -Level Success
        return $true
    }

    # Start the machine
    try {
        Write-Log "  Starting Podman machine..."
        & $podman machine start 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        Write-Log "  Podman machine started" -Level Success
        return $true
    } catch {
        Write-Log "  Failed to start Podman machine: $_" -Level Error
        return $false
    }
}

function Get-WSL2IP {
    Write-Log "Getting WSL2 IP address..."

    try {
        $wslOutput = wsl hostname -I 2>&1
        $ip = ($wslOutput -split '\s+')[0]
        if ($ip -match '^\d+\.\d+\.\d+\.\d+$') {
            Write-Log "  WSL2 IP: $ip" -Level Success
            return $ip
        }
    } catch {
        Write-Log "  Failed to get WSL2 IP: $_" -Level Warning
    }

    return $null
}
