# Infrastructure access tools - works when connected to VPN
{ config, pkgs, lib, ... }:

{
  # Infrastructure management tools (from shared package)
  environment.systemPackages =
    let
      infraTools = import ../../packages/infrastructure-tools.nix { inherit pkgs lib; };
    in
      infraTools.infrastructureTools;

  # VPN client configuration
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # Firewall rules for VPN
  networking.firewall = {
    # Allow Tailscale
    allowedUDPPorts = [ 41641 ];
    # Trust VPN interface
    trustedInterfaces = [ "tailscale0" ];
  };

  # DNS configuration for internal services (when VPN connected)
  networking.extraHosts =
    let
      primaryDomain = lib.strings.removeSuffix "\n" (builtins.readFile config.sops.secrets."domains/primary".path);
    in ''
      # Internal infrastructure services (via VPN)
      192.0.2.1 management.internal.${primaryDomain}
      192.0.2.1 grafana.internal.${primaryDomain}
      192.0.2.1 prometheus.internal.${primaryDomain}
    '';

  # kubectl configuration
  environment.etc."kubectl/config".text =
    let
      primaryDomain = lib.strings.removeSuffix "\n" (builtins.readFile config.sops.secrets."domains/primary".path);
    in ''
      apiVersion: v1
      kind: Config
      clusters:
      - cluster:
          server: https://management.internal.${primaryDomain}:6443
          # Certificate will be added when connected to infrastructure
        name: management
      contexts:
      - context:
          cluster: management
          user: developer
        name: management
      current-context: management
      users:
      - name: developer
        user:
          # Certificate-based auth (to be configured manually)
          client-certificate: ~/.kube/client.crt
          client-key: ~/.kube/client.key
    '';

  # Create kube directory
  systemd.tmpfiles.rules =
    let
      userName = lib.strings.removeSuffix "\n" (builtins.readFile config.sops.secrets."user/name".path);
    in [
      "d /home/${userName}/.kube 0755 ${userName} users -"
    ];

  # Development shell with infrastructure tools
  # This gets activated when in a directory with infrastructure code
  programs.direnv.enable = true;
}
