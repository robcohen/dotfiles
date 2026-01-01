# NixOS system configurations
# Defines WORKSTATION configurations using mkNixosConfig
# Infrastructure hosts (ca-offline, nixtv-player, nas-*) are in infra-private
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
    };
  };
}
