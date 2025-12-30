# modules/travel-router.nix
# Travel router module with WiFi AP, WireGuard VPN, and web UI
#
# Usage:
#   travelRouter.enable = true;
#   travelRouter.apInterface = "wlan0";
#   travelRouter.webUI.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.travelRouter;

  # Router Web UI (Python Flask) - loaded from external file for maintainability
  routerUI = pkgs.writeTextFile {
    name = "router-ui";
    destination = "/share/router-ui/app.py";
    text = builtins.readFile ./travel-router-ui.py;
    executable = true;
  };

  pythonWithFlask = pkgs.python3.withPackages (ps: with ps; [
    flask
    requests
    psutil
  ]);
in
{
  options.travelRouter = {
    enable = lib.mkEnableOption "Travel router functionality with WiFi AP and VPN";

    apInterface = lib.mkOption {
      type = lib.types.str;
      default = "wlan0";
      description = "Wireless interface for AP mode";
    };

    dhcpRange = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.100,10.42.0.250,24h";
      description = "DHCP range for connected clients";
    };

    webUI = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable web management UI";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 80;
        description = "Port for web UI";
      };
    };

    hotspot = {
      ssid = lib.mkOption {
        type = lib.types.str;
        default = "TravelRouter";
        description = "Default SSID for the hotspot";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to file containing hotspot password.
          If null, hotspot toggle will fail until configured via web UI.
          Password must be at least 8 characters for WPA2.
        '';
        example = "/run/secrets/hotspot-password";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # IP forwarding for routing
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # NetworkManager for WiFi client/AP management
    networking.networkmanager = {
      enable = true;
      wifi.backend = "wpa_supplicant";
    };
    networking.wireless.enable = false;

    # WireGuard
    networking.wireguard.enable = true;

    # Firewall
    networking.firewall = {
      allowedTCPPorts = [ 22 cfg.webUI.port ];
      allowedUDPPorts = [ 51820 ]; # WireGuard
    };

    # dnsmasq for DHCP when in AP mode
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = cfg.apInterface;
        bind-interfaces = true;
        dhcp-range = cfg.dhcpRange;
        dhcp-option = [ "option:router,10.42.0.1" ];
      };
    };

    # WireGuard config directory
    systemd.tmpfiles.rules = [
      "d /etc/wireguard 0700 root root -"
    ];

    # Web UI service
    systemd.services.router-ui = lib.mkIf cfg.webUI.enable {
      description = "Travel Router Web UI";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = {
        HOTSPOT_SSID = cfg.hotspot.ssid;
      } // lib.optionalAttrs (cfg.hotspot.passwordFile != null) {
        HOTSPOT_PASSWORD_FILE = cfg.hotspot.passwordFile;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pythonWithFlask}/bin/python ${routerUI}/share/router-ui/app.py";
        Restart = "always";
        RestartSec = 5;
      };
    };

    environment.systemPackages = with pkgs; [
      iw
      wirelesstools
      ethtool
      wireguard-tools
      tcpdump
      nmap
      iperf3
      pythonWithFlask
    ];
  };
}
