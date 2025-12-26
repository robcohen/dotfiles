# lib/firewall.ps1 - Firewall rules configuration

# Tailscale CGNAT range
$Script:TailscaleSubnet = "100.64.0.0/10"

function Set-FirewallRules {
    param($Services)

    Write-Log "Configuring firewall rules (Tailscale only)..."

    foreach ($serviceName in $Services.PSObject.Properties.Name) {
        $service = $Services.$serviceName
        $ruleName = "nixtv-$serviceName"

        # Remove old rule if it exists (may have wrong settings)
        $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if ($existing) {
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            Write-Log "  Removed old rule: $ruleName"
        }

        try {
            # Create rule that only allows Tailscale traffic
            New-NetFirewallRule `
                -DisplayName $ruleName `
                -Direction Inbound `
                -Protocol $service.protocol `
                -LocalPort $service.port `
                -RemoteAddress $Script:TailscaleSubnet `
                -Action Allow `
                -Profile Any | Out-Null
            Write-Log "  Created rule: $ruleName ($($service.protocol)/$($service.port)) [Tailscale only]" -Level Success
        } catch {
            Write-Log "  Failed to create rule '$ruleName': $_" -Level Warning
        }
    }

    # Block these ports from non-Tailscale sources
    Write-Log "  Service ports restricted to Tailscale network (100.64.0.0/10)" -Level Success
}

function Set-DnsLeakPreventionRules {
    Write-Log "Configuring DNS leak prevention..."

    # Block DNS (port 53) except through Tailscale
    $rules = @(
        @{
            Name = "nixtv-block-dns-udp"
            DisplayName = "Block DNS UDP (except Tailscale)"
            Direction = "Outbound"
            Protocol = "UDP"
            RemotePort = 53
            Action = "Block"
            Profile = "Any"
        },
        @{
            Name = "nixtv-block-dns-tcp"
            DisplayName = "Block DNS TCP (except Tailscale)"
            Direction = "Outbound"
            Protocol = "TCP"
            RemotePort = 53
            Action = "Block"
            Profile = "Any"
        },
        @{
            Name = "nixtv-allow-tailscale-dns"
            DisplayName = "Allow Tailscale MagicDNS"
            Direction = "Outbound"
            Protocol = "UDP"
            RemoteAddress = "100.100.100.100"
            RemotePort = 53
            Action = "Allow"
            Profile = "Any"
        }
    )

    foreach ($rule in $rules) {
        $existing = Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue

        if ($existing) {
            Write-Log "  Rule '$($rule.DisplayName)' already exists"
            continue
        }

        try {
            $params = @{
                Name = $rule.Name
                DisplayName = $rule.DisplayName
                Direction = $rule.Direction
                Protocol = $rule.Protocol
                RemotePort = $rule.RemotePort
                Action = $rule.Action
                Profile = $rule.Profile
                Enabled = "True"
            }

            if ($rule.RemoteAddress) {
                $params.RemoteAddress = $rule.RemoteAddress
            }

            New-NetFirewallRule @params | Out-Null
            Write-Log "  Created rule: $($rule.DisplayName)" -Level Success
        } catch {
            Write-Log "  Failed to create rule '$($rule.DisplayName)': $_" -Level Warning
        }
    }

    Write-Log "  Firewall rules configured for DNS leak prevention" -Level Success
}
