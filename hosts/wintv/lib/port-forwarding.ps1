# lib/port-forwarding.ps1 - WSL2 port forwarding via netsh portproxy

function Get-TailscaleIP {
    Write-Log "Getting Tailscale IP address..."

    try {
        $tailscale = Get-TailscaleExecutable
        if ($tailscale) {
            $status = & $tailscale ip -4 2>&1
            if ($status -match '^100\.') {
                Write-Log "  Tailscale IP: $status" -Level Success
                return $status.Trim()
            }
        }

        # Fallback: check network adapters
        $tailscaleAdapter = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -match '^100\.' } |
            Select-Object -First 1

        if ($tailscaleAdapter) {
            Write-Log "  Tailscale IP: $($tailscaleAdapter.IPAddress)" -Level Success
            return $tailscaleAdapter.IPAddress
        }

        Write-Log "  Tailscale IP not found - is Tailscale connected?" -Level Warning
        return $null
    } catch {
        Write-Log "  Failed to get Tailscale IP: $_" -Level Warning
        return $null
    }
}

function Set-PortForwarding {
    param($Services)

    Write-Log "Configuring port forwarding (Tailscale only)..."

    # Ensure IP Helper service is running (required for portproxy)
    $iphlpsvc = Get-Service -Name iphlpsvc -ErrorAction SilentlyContinue
    if ($iphlpsvc.Status -ne "Running") {
        Write-Log "  Starting IP Helper service..."
        Start-Service -Name iphlpsvc
        Set-Service -Name iphlpsvc -StartupType Automatic
    }

    # Get Tailscale IP to bind to
    $tailscaleIP = Get-TailscaleIP
    if (-not $tailscaleIP) {
        Write-Log "  Cannot get Tailscale IP - services will not be accessible" -Level Error
        return $false
    }

    # Get WSL2 IP
    $wslIP = Get-WSL2IP
    if (-not $wslIP) {
        Write-Log "  Cannot get WSL2 IP - is WSL running?" -Level Error
        return $false
    }

    foreach ($serviceName in $Services.PSObject.Properties.Name) {
        $service = $Services.$serviceName

        # Only forward TCP ports
        if ($service.protocol -ne "TCP") {
            continue
        }

        $port = $service.port

        # Remove any existing rules for this port (old 0.0.0.0 or stale Tailscale IP)
        netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>&1 | Out-Null
        netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$tailscaleIP 2>&1 | Out-Null

        try {
            # Bind only to Tailscale IP - not accessible from LAN or internet
            netsh interface portproxy add v4tov4 listenport=$port listenaddress=$tailscaleIP connectport=$port connectaddress=$wslIP 2>&1 | Out-Null
            Write-Log "  $tailscaleIP:$port -> $wslIP:$port ($serviceName)" -Level Success
        } catch {
            Write-Log "  Failed to forward port $port : $_" -Level Warning
        }
    }

    Write-Log "  Services only accessible via Tailscale at $tailscaleIP" -Level Success
    return $true
}

function Remove-PortForwarding {
    param($Services)

    Write-Log "Removing port forwarding rules..."

    $tailscaleIP = Get-TailscaleIP

    foreach ($serviceName in $Services.PSObject.Properties.Name) {
        $service = $Services.$serviceName

        if ($service.protocol -ne "TCP") {
            continue
        }

        $port = $service.port

        # Remove both old-style (0.0.0.0) and new-style (Tailscale IP) rules
        netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>&1 | Out-Null
        if ($tailscaleIP) {
            netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$tailscaleIP 2>&1 | Out-Null
        }
        Write-Log "  Removed port forward for $port" -Level Success
    }
}

function Show-PortForwardingStatus {
    Write-Log "Current port forwarding rules:"
    $rules = netsh interface portproxy show v4tov4
    foreach ($line in $rules) {
        Write-Log "  $line"
    }
}

function Update-PortForwardingForWSL {
    param($Services)

    # WSL2 IP changes on restart, so we need to update the rules
    Write-Log "Updating port forwarding rules for new WSL2 IP..."

    Remove-PortForwarding -Services $Services
    Set-PortForwarding -Services $Services
}
