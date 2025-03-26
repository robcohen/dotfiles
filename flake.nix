{
  description = "Rob Cohen nix config";

  inputs = {
    stable-nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    unstable-nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "stable-nixpkgs";
    hardware.url = "github:nixos/nixos-hardware";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
  };

  outputs = inputs@{ self, stable-nixpkgs, unstable-nixpkgs, home-manager, sops-nix, nixos-cosmic, ... }:
    let
      system = "x86_64-linux";

      unstable-patched = import unstable-nixpkgs {
        inherit system;
        overlays = [ nixos-cosmic.overlays.default ];
      };

      unstable = import inputs.unstable-nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkHomeConfig = hostname: home-manager.lib.homeManagerConfiguration {
        pkgs = stable-nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit inputs unstable;
        };
        modules = [ ./profiles/user.nix ];
      };
    in {
      nixosConfigurations = {
        slax = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            unstable = unstable-nixpkgs.legacyPackages.${system};
          };
          modules = [
            ./hosts/slax/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };

        brix = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            unstable = unstable-patched;
          };
          modules = [
            nixos-cosmic.nixosModules.default
            ./hosts/brix/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };
      };

      homeConfigurations = {
        "user@slax" = mkHomeConfig "slax";
        "user@brix" = mkHomeConfig "brix";
      };

      formatter.${system} = stable-nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    };
}
