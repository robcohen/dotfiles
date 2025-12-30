# Shared module arguments
# Makes builders and constants available to all flake-parts modules
{
  inputs,
  self,
  ...
}:

let
  # Import library modules
  constants = import ../lib/constants.nix;
  systemBuilders = import ../lib/system-builders.nix { inherit inputs self; };
  homeBuilders = import ../lib/home-builders.nix { inherit inputs self systemBuilders; };
in
{
  # Make builders available to all flake-level modules
  _module.args = {
    inherit constants systemBuilders homeBuilders;
  };

  # perSystem provides system-specific args
  perSystem =
    { system, ... }:
    {
      _module.args = {
        # System-aware package sets
        pkgs = systemBuilders.pkgsFor system;
        unstablePkgs = systemBuilders.unstablePkgsFor system;

        # System-aware specialArgs for nixos-generators
        mkSpecialArgs = systemBuilders.mkSpecialArgs system;
      };
    };
}
