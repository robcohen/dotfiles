{ config, pkgs, lib, ... }:

let
  hostname = builtins.readFile /etc/hostname;
  cleanHostname = lib.strings.removeSuffix "\n" hostname;
  
  # Simple validation with defaults
  hostType = "desktop";
  hostFeatures = [];
  
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