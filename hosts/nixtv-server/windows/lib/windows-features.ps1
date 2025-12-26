# lib/windows-features.ps1 - Windows features setup

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
                Set-RebootRequired
            } catch {
                Write-Log "  Failed to enable $($feature.DisplayName): $_" -Level Warning
            }
        }
    }
}

function Install-WSL2 {
    Write-Log "Configuring WSL2..."

    $wsl = Get-Command "wsl" -ErrorAction SilentlyContinue
    if (-not $wsl) {
        Write-Log "  Installing WSL..."
        try {
            wsl --install --no-distribution
            Set-RebootRequired
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
