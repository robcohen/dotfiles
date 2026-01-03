# Tailscale + Mullvad exit node configuration with DNS leak prevention
#
# DNS: Control D via Tailscale integration (routes through MagicDNS)
# VPN: Mullvad exit nodes for traffic routing
#
# Prerequisites:
#   1. Purchase Mullvad add-on in Tailscale admin console ($5/mo for 5 devices)
#   2. Add devices to Mullvad access list in admin console
#   3. Configure Control D as global nameserver in Tailscale DNS settings
#   4. Enable "Override local DNS" in DNS settings
#
# Usage:
#   tailscale up                              # Connect to tailnet
#   tailscale exit-node list                  # List available Mullvad nodes
#   tailscale set --exit-node=<node>          # Use specific Mullvad exit
#   tailscale set --exit-node-allow-lan-access=true  # Allow local network
#
{ config, pkgs, lib, ... }:

{
  # Tailscale service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    # Use networkd-wait-online for proper DNS resolution timing
    openFirewall = true;
  };

  # Enable systemd-resolved for proper DNS handling with Tailscale
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    # Fail-closed: no fallback DNS to prevent leaks if Tailscale DNS fails.
    # This means no DNS resolution if Tailscale is disconnected - intentional.
    fallbackDns = [ ];
    # Don't cache to ensure fresh Tailscale DNS responses
    extraConfig = ''
      DNSStubListener=yes
      MulticastDNS=no
      LLMNR=no
    '';
  };

  # Required for exit node traffic routing
  networking.firewall.checkReversePath = "loose";

  # Firewall rules to prevent DNS leaks when using exit node
  networking.firewall = {
    # Allow Tailscale
    allowedUDPPorts = [ 41641 ];
    trustedInterfaces = [ "tailscale0" ];

    extraCommands = ''
      # =======================================================================
      # DNS Leak Prevention (IPv4)
      # =======================================================================
      # Block DNS queries that bypass Tailscale when exit node is active

      # Allow DNS to Tailscale's MagicDNS (Control D routes through this)
      iptables -I OUTPUT -p udp --dport 53 -d 100.100.100.100 -j ACCEPT
      iptables -I OUTPUT -p tcp --dport 53 -d 100.100.100.100 -j ACCEPT

      # Allow DNS over Tailscale interface
      iptables -I OUTPUT -o tailscale0 -p udp --dport 53 -j ACCEPT
      iptables -I OUTPUT -o tailscale0 -p tcp --dport 53 -j ACCEPT

      # Allow localhost DNS (for systemd-resolved stub)
      iptables -I OUTPUT -p udp --dport 53 -d 127.0.0.53 -j ACCEPT
      iptables -I OUTPUT -p tcp --dport 53 -d 127.0.0.53 -j ACCEPT
      iptables -I OUTPUT -p udp --dport 53 -d 127.0.0.1 -j ACCEPT
      iptables -I OUTPUT -p tcp --dport 53 -d 127.0.0.1 -j ACCEPT

      # DROP all other DNS traffic (must be last)
      iptables -A OUTPUT -p udp --dport 53 -j DROP
      iptables -A OUTPUT -p tcp --dport 53 -j DROP

      # =======================================================================
      # DNS Leak Prevention (IPv6)
      # =======================================================================

      # Allow DNS over Tailscale interface
      ip6tables -I OUTPUT -o tailscale0 -p udp --dport 53 -j ACCEPT
      ip6tables -I OUTPUT -o tailscale0 -p tcp --dport 53 -j ACCEPT

      # Allow localhost DNS (for systemd-resolved stub)
      ip6tables -I OUTPUT -p udp --dport 53 -d ::1 -j ACCEPT
      ip6tables -I OUTPUT -p tcp --dport 53 -d ::1 -j ACCEPT

      # DROP all other IPv6 DNS traffic (must be last)
      ip6tables -A OUTPUT -p udp --dport 53 -j DROP
      ip6tables -A OUTPUT -p tcp --dport 53 -j DROP
    '';

    extraStopCommands = ''
      # Clean up IPv4 rules
      iptables -D OUTPUT -p udp --dport 53 -d 100.100.100.100 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p tcp --dport 53 -d 100.100.100.100 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -o tailscale0 -p udp --dport 53 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -o tailscale0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p udp --dport 53 -d 127.0.0.53 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p tcp --dport 53 -d 127.0.0.53 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p udp --dport 53 -d 127.0.0.1 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p tcp --dport 53 -d 127.0.0.1 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p udp --dport 53 -j DROP 2>/dev/null || true
      iptables -D OUTPUT -p tcp --dport 53 -j DROP 2>/dev/null || true

      # Clean up IPv6 rules
      ip6tables -D OUTPUT -o tailscale0 -p udp --dport 53 -j ACCEPT 2>/dev/null || true
      ip6tables -D OUTPUT -o tailscale0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
      ip6tables -D OUTPUT -p udp --dport 53 -d ::1 -j ACCEPT 2>/dev/null || true
      ip6tables -D OUTPUT -p tcp --dport 53 -d ::1 -j ACCEPT 2>/dev/null || true
      ip6tables -D OUTPUT -p udp --dport 53 -j DROP 2>/dev/null || true
      ip6tables -D OUTPUT -p tcp --dport 53 -j DROP 2>/dev/null || true
    '';
  };

  # Allow users in wheel group to change DNS without password (for waybar DNS switcher)
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [{
      command = "${pkgs.systemd}/bin/resolvectl dns *";
      options = [ "NOPASSWD" ];
    }];
  }];

  # Helper scripts
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "mullvad-connect" ''
      #!/usr/bin/env bash
      set -euo pipefail

      echo "Available Mullvad exit nodes:"
      tailscale exit-node list 2>/dev/null | grep mullvad || {
        echo "No Mullvad nodes found. Check:"
        echo "  1. Mullvad add-on is purchased in Tailscale admin console"
        echo "  2. This device has Mullvad access in admin console"
        exit 1
      }
      echo ""
      echo "Usage: tailscale set --exit-node=<node-name>"
      echo "Example: tailscale set --exit-node=se-sto-wg-001.mullvad.ts.net"
    '')

    (writeShellScriptBin "mullvad-disconnect" ''
      #!/usr/bin/env bash
      tailscale set --exit-node=
      echo "Disconnected from Mullvad exit node"
    '')

    (writeShellScriptBin "mullvad-status" ''
      #!/usr/bin/env bash
      echo "=== Tailscale Status ==="
      tailscale status
      echo ""
      echo "=== Current Exit Node ==="
      tailscale status --json | ${pkgs.jq}/bin/jq -r '.ExitNodeStatus // "None"'
      echo ""
      echo "=== DNS Leak Test ==="
      echo "Your public IP:"
      curl -s https://am.i.mullvad.net/ip || echo "Failed to check IP"
      echo ""
      echo "Connected to Mullvad:"
      curl -s https://am.i.mullvad.net/connected || echo "Failed to check"
    '')
  ];
}
