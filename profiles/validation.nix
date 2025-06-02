{ config, pkgs, lib, ... }:

let
  vars = import ../lib/vars.nix;
  hostname = builtins.readFile /etc/hostname;
  cleanHostname = lib.strings.removeSuffix "\n" hostname;
  hostConfig = vars.hosts.${cleanHostname} or {};
  
  # Simple validation with defaults
  hostType = hostConfig.type or "desktop";
  hostFeatures = hostConfig.features or [];
  
in {
  # Make host config available to other modules
  _module.args = {
    hostConfig = hostConfig;
    hostFeatures = hostFeatures;
    hostType = hostType;
  };

  # Add some helpful debugging info
  home.file.".config/home-manager/host-info.txt".text = ''
    Host: ${cleanHostname}
    Type: ${hostType}
    Features: ${lib.concatStringsSep ", " hostFeatures}
    State Version: ${hostConfig.homeManagerStateVersion or "unknown"}
  '';
}