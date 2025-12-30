{ config, pkgs, lib, hostname ? null, ... }:

let
  # Safely read hostname with fallback
  detectedHostname =
    if hostname != null then hostname
    else if builtins.pathExists /etc/hostname
    then lib.strings.removeSuffix "\n" (builtins.readFile /etc/hostname)
    else "unknown";

  # Simple validation with defaults
  hostType = "desktop";
  hostFeatures = [];

in {
  # Make host config available to other modules
  _module.args = {
    hostFeatures = hostFeatures;
    hostType = hostType;
  };

  # Add some helpful debugging info
  home.file.".config/home-manager/host-info.txt".text = ''
    Host: ${detectedHostname}
    Type: ${hostType}
    Features: ${lib.concatStringsSep ", " hostFeatures}
  '';
}
