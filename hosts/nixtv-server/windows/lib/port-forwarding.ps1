# lib/port-forwarding.ps1 - WSL2 port forwarding via netsh portproxy

function Set-PortForwarding {
    param($Services)

    Write-Log "Configuring port forwarding from Windows to WSL2..."

    # Ensure IP Helper service is running (required for portproxy)
    $iphlpsvc = Get-Service -Name iphlpsvc -ErrorAction SilentlyContinue
    if ($iphlpsvc.Status -ne "Running") {
        Write-Log "  Starting IP Helper service..."
        Start-Service -Name iphlpsvc
        Set-Service -Name iphlpsvc -StartupType Automatic
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

        # Check if rule already exists
        $existing = netsh interface portproxy show v4tov4 | Select-String -Pattern "0.0.0.0\s+$port"

        if ($existing) {
            # Update existing rule with new WSL IP
            netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>&1 | Out-Null
        }

        try {
            netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIP 2>&1 | Out-Null
            Write-Log "  Port $port -> $wslIP:$port ($serviceName)" -Level Success
        } catch {
            Write-Log "  Failed to forward port $port : $_" -Level Warning
        }
    }

    return $true
}

function Remove-PortForwarding {
    param($Services)

    Write-Log "Removing port forwarding rules..."

    foreach ($serviceName in $Services.PSObject.Properties.Name) {
        $service = $Services.$serviceName

        if ($service.protocol -ne "TCP") {
            continue
        }

        $port = $service.port

        try {
            netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>&1 | Out-Null
            Write-Log "  Removed port forward for $port" -Level Success
        } catch {
            Write-Log "  No rule found for port $port"
        }
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
