# lib/caddy.ps1 - Caddy reverse proxy with Tailscale HTTPS

function Get-TailscaleDomain {
    try {
        $status = tailscale status --json 2>&1 | ConvertFrom-Json
        $self = $status.Self
        if ($self.DNSName) {
            # Remove trailing dot
            return $self.DNSName.TrimEnd('.')
        }
    } catch {}

    # Fallback: try to get from tailscale status output
    try {
        $status = tailscale status 2>&1
        $line = $status | Select-String $env:COMPUTERNAME
        if ($line -match '(\S+\.ts\.net)') {
            return $Matches[1]
        }
    } catch {}

    return $null
}

function New-TailscaleCert {
    param($Config)

    Write-Log "Generating Tailscale HTTPS certificate..."

    $domain = Get-TailscaleDomain
    if (-not $domain) {
        Write-Log "  Could not determine Tailscale domain" -Level Error
        Write-Log "  Ensure Tailscale is connected and HTTPS is enabled in admin console" -Level Info
        return $false
    }

    Write-Log "  Domain: $domain"

    $certDir = "$($Config.paths.appData)\certs"
    if (-not (Test-Path $certDir)) {
        New-Item -ItemType Directory -Path $certDir -Force | Out-Null
    }

    try {
        Push-Location $certDir
        tailscale cert $domain 2>&1
        Pop-Location

        if (Test-Path "$certDir\$domain.crt") {
            Write-Log "  Certificate generated" -Level Success
            return $true
        } else {
            Write-Log "  Certificate generation failed" -Level Error
            return $false
        }
    } catch {
        Pop-Location
        Write-Log "  Failed to generate certificate: $_" -Level Error
        return $false
    }
}

function Install-Caddyfile {
    param($Config)

    Write-Log "Installing Caddyfile..."

    $scriptRoot = Get-ScriptRoot
    $caddyfileSource = Join-Path $scriptRoot "configs\Caddyfile"
    $caddyDir = "$($Config.paths.appData)\Caddy"
    $caddyfileDest = "$caddyDir\Caddyfile"

    # Create directory
    if (-not (Test-Path $caddyDir)) {
        New-Item -ItemType Directory -Path $caddyDir -Force | Out-Null
        New-Item -ItemType Directory -Path "$caddyDir\data" -Force | Out-Null
        New-Item -ItemType Directory -Path "$caddyDir\config" -Force | Out-Null
    }

    # Copy Caddyfile with domain replacement
    if (Test-Path $caddyfileSource) {
        $domain = Get-TailscaleDomain
        if (-not $domain) {
            Write-Log "  Cannot get Tailscale domain - Caddyfile will need manual editing" -Level Warning
            Copy-Item $caddyfileSource $caddyfileDest -Force
        } else {
            $content = Get-Content $caddyfileSource -Raw
            $content = $content -replace '\{DOMAIN\}', $domain
            Set-Content -Path $caddyfileDest -Value $content -NoNewline
            Write-Log "  Caddyfile installed for $domain" -Level Success
        }
        return $true
    } else {
        Write-Log "  Caddyfile not found at $caddyfileSource" -Level Error
        return $false
    }
}

function Start-CaddyContainer {
    param($Config)

    Write-Log "Starting Caddy container..."

    # Check if already running
    $existing = podman ps --filter name=caddy --format "{{.Names}}" 2>$null
    if ($existing -eq "caddy") {
        Write-Log "  Caddy already running" -Level Success
        return $true
    }

    # Remove if exists but stopped
    podman rm -f caddy 2>&1 | Out-Null

    $caddyDir = "$($Config.paths.appData)\Caddy"
    $certDir = "$($Config.paths.appData)\certs"

    try {
        podman run -d `
            --name caddy `
            --restart unless-stopped `
            -p 443:443 `
            -p 80:80 `
            -v "${caddyDir}\Caddyfile:/etc/caddy/Caddyfile:ro" `
            -v "${certDir}:/certs:ro" `
            -v "${caddyDir}\data:/data" `
            -v "${caddyDir}\config:/config" `
            caddy:latest 2>&1

        Start-Sleep -Seconds 3

        $status = podman ps --filter name=caddy --format "{{.Status}}" 2>$null
        if ($status -match "Up") {
            Write-Log "  Caddy started" -Level Success
            return $true
        } else {
            Write-Log "  Caddy failed to start" -Level Error
            podman logs caddy 2>&1 | Select-Object -Last 10
            return $false
        }
    } catch {
        Write-Log "  Failed to start Caddy: $_" -Level Error
        return $false
    }
}

function Initialize-Caddy {
    param($Config)

    Write-Log "Initializing Caddy reverse proxy..."

    # Ensure privileged ports are accessible
    Set-PrivilegedPortAccess

    # Generate Tailscale cert
    if (-not (New-TailscaleCert -Config $Config)) {
        Write-Log "  Continuing without HTTPS cert..." -Level Warning
    }

    # Install Caddyfile
    Install-Caddyfile -Config $Config

    # Start container
    Start-CaddyContainer -Config $Config

    # Add port forwarding for 443/80
    $wslIP = Get-PodmanMachineIP
    $tailscaleIP = Get-TailscaleIP
    if ($wslIP -and $tailscaleIP) {
        netsh interface portproxy add v4tov4 listenport=443 listenaddress=$tailscaleIP connectport=443 connectaddress=$wslIP 2>&1 | Out-Null
        netsh interface portproxy add v4tov4 listenport=80 listenaddress=$tailscaleIP connectport=80 connectaddress=$wslIP 2>&1 | Out-Null
        Write-Log "  Port forwarding configured for 443/80" -Level Success
    }
}

function Get-PodmanMachineIP {
    try {
        # Get IP from existing port proxy rules
        $rules = netsh interface portproxy show v4tov4 2>&1
        if ($rules -match '(\d+\.\d+\.\d+\.\d+)\s+7575') {
            return $Matches[1]
        }

        # Fallback: try to get from podman machine
        $ip = podman machine ssh "ip -4 addr show eth0 | grep inet | awk '{print \$2}' | cut -d/ -f1" 2>&1
        if ($ip -match '^\d+\.\d+\.\d+\.\d+$') {
            return $ip.Trim()
        }
    } catch {}

    return $null
}
