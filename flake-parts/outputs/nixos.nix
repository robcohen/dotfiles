# NixOS system configurations
# Defines all host configurations using mkNixosConfig
{ inputs, self, ... }:

let
  # Import builders directly since flake outputs don't receive _module.args
  systemBuilders = import ../../lib/system-builders.nix { inherit inputs self; };
  inherit (systemBuilders) mkNixosConfig;
in
{
  flake = {
    nixosConfigurations = {
      slax = mkNixosConfig { hostConfig = "${self}/hosts/slax/configuration.nix"; };

      brix = mkNixosConfig { hostConfig = "${self}/hosts/brix/configuration.nix"; };

      snix = mkNixosConfig { hostConfig = "${self}/hosts/snix/configuration.nix"; };

      # nixtv-player is a dedicated appliance - no microvm needed
      nixtv-player = mkNixosConfig {
        hostConfig = "${self}/hosts/nixtv-player/configuration.nix";
        extraModules = [
          { microvm.host.enable = false; } # Override microvm from mkNixosConfig
        ];
      };
    };
  };
}
