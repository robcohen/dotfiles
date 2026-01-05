# NixOS configuration builders
# Provides mkNixosConfig and related helper functions
{
  inputs,
  self,
}:

let
  inherit (inputs)
    stable-nixpkgs
    unstable-nixpkgs
    sops-nix
    microvm
    rednix
    disko
    nix-amd-npu
    ;
in
rec {
  # Per-system package sets with unfree allowed
  pkgsFor =
    system:
    import stable-nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

  unstablePkgsFor =
    system:
    import unstable-nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

  # Common specialArgs factory (system-aware)
  # These args are available to all NixOS modules
  mkSpecialArgs = system: {
    inherit inputs microvm rednix disko nix-amd-npu;
    unstable = unstablePkgsFor system;
  };

  # NixOS configuration builder - reduces duplication across hosts
  # Automatically includes sops-nix and microvm host module
  mkNixosConfig =
    {
      system ? "x86_64-linux",
      hostConfig,
      extraModules ? [ ],
    }:
    stable-nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = mkSpecialArgs system;
      modules = [
        hostConfig
        sops-nix.nixosModules.sops
        "${self}/modules/sops.nix"
        microvm.nixosModules.host
      ]
      ++ extraModules;
    };
}
