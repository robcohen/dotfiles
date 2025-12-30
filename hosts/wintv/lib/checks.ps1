# lib/checks.ps1 - System checks for wintv setup

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
            Test = { (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue).State -eq "Enabled" }
        },
        @{
            Name = "NVIDIA GPU"
            Test = { Test-NvidiaGpu }
        },
        @{
            Name = "Python"
            Test = { Test-Path "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\python.exe" }
        },
        @{
            Name = "podman-compose"
            Test = { Test-Path "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\Scripts\podman-compose.exe" }
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
