{ config, pkgs, lib, ... }:

let
  vars = import ../lib/vars.nix;
  hostname = builtins.readFile /etc/hostname;
  cleanHostname = lib.strings.removeSuffix "\n" hostname;
  hostConfig = vars.hosts.${cleanHostname} or null;
  
  # Validation functions
  validHostTypes = [ "desktop" "server" ];
  validFeatures = [ "gaming" "development" "multimedia" "headless" "backup" ];
  
  validateHostConfig = hostConfig:
    if hostConfig == null then
      throw "Host '${cleanHostname}' is not defined in vars.nix. Please add configuration for this host."
    else if !(builtins.elem (hostConfig.type or "unknown") validHostTypes) then
      throw "Invalid host type '${hostConfig.type or "unknown"}' for host '${cleanHostname}'. Valid types: ${lib.concatStringsSep ", " validHostTypes}"
    else if !(builtins.all (feature: builtins.elem feature validFeatures) (hostConfig.features or [])) then
      let invalidFeatures = builtins.filter (feature: !(builtins.elem feature validFeatures)) (hostConfig.features or []);
      in throw "Invalid features for host '${cleanHostname}': ${lib.concatStringsSep ", " invalidFeatures}. Valid features: ${lib.concatStringsSep ", " validFeatures}"
    else
      hostConfig;

  # Validate and get host config
  validatedHostConfig = validateHostConfig hostConfig;

in {
  # Assertions for configuration validation
  assertions = [
    {
      assertion = builtins.pathExists /etc/hostname;
      message = "Cannot read hostname from /etc/hostname. This file is required for host-specific configuration.";
    }
    {
      assertion = hostConfig != null;
      message = "Host configuration for '${cleanHostname}' not found in vars.nix";
    }
    {
      assertion = validatedHostConfig.homeManagerStateVersion or null != null;
      message = "homeManagerStateVersion is required for host '${cleanHostname}' in vars.nix";
    }
    {
      assertion = builtins.match "^[0-9]+\\.[0-9]+$" (validatedHostConfig.homeManagerStateVersion or "") != null;
      message = "homeManagerStateVersion must be in format 'XX.YY' for host '${cleanHostname}'";
    }
  ];

  # Make validated config available to other modules
  _module.args = {
    validatedHostConfig = validatedHostConfig;
    hostFeatures = validatedHostConfig.features or [];
    isDesktop = validatedHostConfig.type or "desktop" == "desktop";
    isServer = validatedHostConfig.type or "desktop" == "server";
  };

  # Add some helpful debugging info as comments in generated files
  home.file.".config/home-manager/host-info.txt".text = ''
    Host: ${cleanHostname}
    Type: ${validatedHostConfig.type or "unknown"}
    Features: ${lib.concatStringsSep ", " (validatedHostConfig.features or [])}
    State Version: ${validatedHostConfig.homeManagerStateVersion or "unknown"}
    Generated: ${builtins.currentTime}
  '';
}