# lib/firewall.ps1 - Firewall rules configuration

function Set-FirewallRules {
    param($Services)

    Write-Log "Configuring firewall rules..."

    foreach ($serviceName in $Services.PSObject.Properties.Name) {
        $service = $Services.$serviceName
        $ruleName = "nixtv-$serviceName"

        # Check if rule exists
        $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

        if ($existing) {
            Write-Log "  Rule '$ruleName' already exists"
        } else {
            try {
                New-NetFirewallRule `
                    -DisplayName $ruleName `
                    -Direction Inbound `
                    -Protocol $service.protocol `
                    -LocalPort $service.port `
                    -Action Allow `
                    -Profile Private,Domain | Out-Null
                Write-Log "  Created rule: $ruleName ($($service.protocol)/$($service.port))" -Level Success
            } catch {
                Write-Log "  Failed to create rule '$ruleName': $_" -Level Warning
            }
        }
    }
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
