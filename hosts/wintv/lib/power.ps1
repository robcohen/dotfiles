# lib/power.ps1 - Power settings configuration

function Set-PowerSettings {
    Write-Log "Configuring power settings..."

    try {
        # Never sleep when plugged in (AC)
        powercfg /change standby-timeout-ac 0
        Write-Log "  AC standby timeout: Never" -Level Success

        # Never sleep on battery (if applicable)
        powercfg /change standby-timeout-dc 0
        Write-Log "  DC standby timeout: Never" -Level Success

        # Never turn off display when plugged in
        powercfg /change monitor-timeout-ac 0
        Write-Log "  AC monitor timeout: Never" -Level Success

        # Never turn off display on battery
        powercfg /change monitor-timeout-dc 0
        Write-Log "  DC monitor timeout: Never" -Level Success

        # Never hibernate
        powercfg /change hibernate-timeout-ac 0
        powercfg /change hibernate-timeout-dc 0
        Write-Log "  Hibernate timeout: Never" -Level Success

        # Disable hibernate completely (frees up disk space)
        powercfg /hibernate off 2>&1 | Out-Null
        Write-Log "  Hibernate disabled" -Level Success

    } catch {
        Write-Log "  Failed to configure power settings: $_" -Level Warning
    }
}

function Set-HighPerformancePowerPlan {
    Write-Log "Setting High Performance power plan..."

    try {
        # Get High Performance power plan GUID
        $highPerfGuid = (powercfg /list | Select-String "High performance" | ForEach-Object {
            $_ -match '([a-f0-9-]{36})' | Out-Null
            $matches[1]
        })

        if ($highPerfGuid) {
            powercfg /setactive $highPerfGuid
            Write-Log "  High Performance power plan activated" -Level Success
        } else {
            Write-Log "  High Performance power plan not found" -Level Warning
        }
    } catch {
        Write-Log "  Failed to set power plan: $_" -Level Warning
    }
}

function Show-PowerSettings {
    Write-Log "Current power settings:"

    $activeScheme = powercfg /getactivescheme
    Write-Log "  Active scheme: $activeScheme"

    $settings = @(
        @{ Name = "Standby (AC)"; Query = "powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE" },
        @{ Name = "Monitor (AC)"; Query = "powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE" }
    )

    foreach ($setting in $settings) {
        $result = Invoke-Expression $setting.Query 2>&1 | Select-String "Current AC Power Setting"
        if ($result) {
            Write-Log "  $($setting.Name): $result"
        }
    }
}
