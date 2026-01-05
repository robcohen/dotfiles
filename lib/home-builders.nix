# Home Manager configuration builders
# Provides mkHomeConfig with hostname/hostType/hostFeatures support
{
  inputs,
  self,
  systemBuilders,
}:

let
  inherit (inputs) home-manager sops-nix;
  inherit (systemBuilders) pkgsFor mkSpecialArgs;
  constants = import ./constants.nix;
in
rec {
  # Home-manager configuration builder with hostname support
  # Passes hostname, username, hostType, hostFeatures to all modules
  mkHomeConfig =
    {
      system ? "x86_64-linux",
      hostname,
      username ? constants.defaults.username,
      hostType ? constants.defaults.hostType,
      hostFeatures ? constants.defaults.hostFeatures,
      extraModules ? [ ],
    }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor system;
      extraSpecialArgs = (mkSpecialArgs system) // {
        inherit
          hostname
          username
          hostType
          hostFeatures
          ;
        hostConfig = { }; # Placeholder for compatibility
      };
      modules = [
        sops-nix.homeManagerModules.sops
        "${self}/profiles/user.nix"
      ]
      ++ extraModules;
    };
}
