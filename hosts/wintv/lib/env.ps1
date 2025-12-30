# lib/env.ps1 - Environment variable management

function Get-EnvFilePath {
    return Join-Path (Get-ScriptRoot) ".env"
}

function Get-EnvExamplePath {
    return Join-Path (Get-ScriptRoot) ".env.example"
}

function Test-EnvFile {
    $envPath = Get-EnvFilePath
    return Test-Path $envPath
}

function Import-EnvFile {
    param(
        [string]$Path,
        [switch]$SetMachine,
        [switch]$Quiet
    )

    if (-not $Path) {
        $Path = Get-EnvFilePath
    }

    if (-not (Test-Path $Path)) {
        if (-not $Quiet) {
            Write-Log ".env file not found at $Path" -Level Warning
            Write-Log "Copy .env.example to .env and configure your settings" -Level Info
        }
        return $false
    }

    if (-not $Quiet) {
        Write-Log "Loading environment from $Path..."
    }

    $content = Get-Content $Path -ErrorAction Stop
    $loaded = 0

    foreach ($line in $content) {
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            continue
        }

        # Parse KEY=VALUE
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove surrounding quotes if present
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            # Set process environment variable
            [Environment]::SetEnvironmentVariable($key, $value, "Process")

            # Optionally set machine-level (persistent)
            if ($SetMachine) {
                [Environment]::SetEnvironmentVariable($key, $value, "Machine")
            }

            $loaded++
        }
    }

    if (-not $Quiet) {
        Write-Log "  Loaded $loaded environment variables" -Level Success
    }

    return $true
}

function Export-EnvFile {
    param(
        [hashtable]$Variables,
        [string]$Path
    )

    if (-not $Path) {
        $Path = Get-EnvFilePath
    }

    $content = @()
    $content += "# Auto-generated .env file"
    $content += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $content += ""

    foreach ($key in $Variables.Keys | Sort-Object) {
        $value = $Variables[$key]
        # Quote values with spaces
        if ($value -match '\s') {
            $value = "`"$value`""
        }
        $content += "$key=$value"
    }

    $content | Out-File -FilePath $Path -Encoding UTF8
    Write-Log "Exported environment to $Path" -Level Success
}

function Initialize-EnvFile {
    $envPath = Get-EnvFilePath
    $examplePath = Get-EnvExamplePath

    if (Test-Path $envPath) {
        Write-Log ".env file already exists" -Level Success
        return $true
    }

    if (-not (Test-Path $examplePath)) {
        Write-Log ".env.example not found - cannot initialize .env" -Level Error
        return $false
    }

    Write-Log "Creating .env from .env.example..."
    Copy-Item $examplePath $envPath
    Write-Log ".env file created - please edit with your settings" -Level Warning
    Write-Log "Location: $envPath" -Level Info

    return $true
}

function Get-EnvVariable {
    param([string]$Name, [string]$Default = "")

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrEmpty($value)) {
        return $Default
    }
    return $value
}

function Set-EnvVariable {
    param(
        [string]$Name,
        [string]$Value,
        [switch]$Persistent
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, "Process")

    if ($Persistent) {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Machine")
        Write-Log "Set $Name (persistent)" -Level Success
    }
}

function Show-EnvVariables {
    Write-Log "Current wintv environment variables:"

    $envVars = @(
        "TZ", "PUID", "PGID",
        "MEDIA_PATH", "APPDATA_PATH",
        "TAILSCALE_AUTHKEY",
        "NOTIFIARR_API_KEY",
        "WATCHTOWER_NOTIFICATION_URL"
    )

    foreach ($var in $envVars) {
        $value = Get-EnvVariable -Name $var
        if ($value) {
            # Mask sensitive values
            if ($var -match "KEY|SECRET|PASSWORD|TOKEN") {
                $masked = $value.Substring(0, [Math]::Min(4, $value.Length)) + "****"
                Write-Log "  $var = $masked"
            } else {
                Write-Log "  $var = $value"
            }
        } else {
            Write-Log "  $var = (not set)" -Level Warning
        }
    }
}
