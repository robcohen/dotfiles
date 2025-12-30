# Home Manager configurations
# Defines user configurations using mkHomeConfig with host-specific features
{ inputs, self, ... }:

let
  # Import builders directly since flake outputs don't receive _module.args
  constants = import ../../lib/constants.nix;
  systemBuilders = import ../../lib/system-builders.nix { inherit inputs self; };
  homeBuilders = import ../../lib/home-builders.nix { inherit inputs self systemBuilders; };
  inherit (homeBuilders) mkHomeConfig;
  inherit (constants) hosts;
in
{
  flake = {
    homeConfigurations = {
      "user@slax" = mkHomeConfig {
        hostname = "slax";
        hostFeatures = hosts.slax.hostFeatures;
      };

      "user@brix" = mkHomeConfig {
        hostname = "brix";
        hostFeatures = hosts.brix.hostFeatures;
      };

      "user@snix" = mkHomeConfig {
        hostname = "snix";
        hostFeatures = hosts.snix.hostFeatures;
      };
    };
  };
}
