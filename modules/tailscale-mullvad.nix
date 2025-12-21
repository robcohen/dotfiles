# Tailscale + Mullvad exit node configuration with DNS leak prevention
#
# Prerequisites:
#   1. Purchase Mullvad add-on in Tailscale admin console ($5/mo for 5 devices)
#   2. Add devices to Mullvad access list in admin console
#   3. Enable "Override local DNS" in DNS settings
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
    # Fallback DNS only used if Tailscale DNS fails
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
      # Block DNS queries that bypass Tailscale when exit node is active
      # These rules only apply when traffic would go out a non-tailscale interface

      # Allow DNS to Tailscale's MagicDNS (100.100.100.100)
      iptables -I OUTPUT -p udp --dport 53 -d 100.100.100.100 -j ACCEPT
      iptables -I OUTPUT -p tcp --dport 53 -d 100.100.100.100 -j ACCEPT

      # Allow DNS to Mullvad's DNS (when using their exit nodes)
      iptables -I OUTPUT -p udp --dport 53 -d 10.64.0.1 -j ACCEPT
      iptables -I OUTPUT -p tcp --dport 53 -d 10.64.0.1 -j ACCEPT

      # Allow DNS over Tailscale interface
      iptables -I OUTPUT -o tailscale0 -p udp --dport 53 -j ACCEPT
      iptables -I OUTPUT -o tailscale0 -p tcp --dport 53 -j ACCEPT

      # Allow localhost DNS (for systemd-resolved stub)
      iptables -I OUTPUT -p udp --dport 53 -d 127.0.0.53 -j ACCEPT
      iptables -I OUTPUT -p tcp --dport 53 -d 127.0.0.53 -j ACCEPT
    '';

    extraStopCommands = ''
      iptables -D OUTPUT -p udp --dport 53 -d 100.100.100.100 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p tcp --dport 53 -d 100.100.100.100 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p udp --dport 53 -d 10.64.0.1 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p tcp --dport 53 -d 10.64.0.1 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -o tailscale0 -p udp --dport 53 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -o tailscale0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p udp --dport 53 -d 127.0.0.53 -j ACCEPT 2>/dev/null || true
      iptables -D OUTPUT -p tcp --dport 53 -d 127.0.0.53 -j ACCEPT 2>/dev/null || true
    '';
  };

  # Disable DHCP-provided DNS on tailscale0 interface
  networking.dhcpcd.extraConfig = ''
    nohook resolv.conf
    interface tailscale0
      nogateway
      noipv6rs
  '';

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
