# flake.nix
{
  description = "Rob Cohen nix config";

  nixConfig = {
    extra-substituters = [ "https://cosmic.cachix.org" ];
    extra-trusted-public-keys = [
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
    ];
  };

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
      unstable-nixpkgs-patched = unstable-nixpkgs // {
        overlays = [ nixos-cosmic.overlays.default ];
      };
    in {
      nixosConfigurations = {
        slax = stable-nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            unstable = unstable-nixpkgs.legacyPackages.x86_64-linux;
          };
          modules = [
            ./hosts/slax/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };

        brix = stable-nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            unstable = unstable-nixpkgs-patched.legacyPackages.x86_64-linux;
          };
          modules = [
            nixos-cosmic.nixosModules.default
            ./hosts/brix/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };
      };

      homeConfigurations = {
        "user@slax" = home-manager.lib.homeManagerConfiguration {
          pkgs = stable-nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = [ ./profiles/user.nix ];
        };

        "user@brix" = home-manager.lib.homeManagerConfiguration {
          pkgs = stable-nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = [ ./profiles/user.nix ];
        };
      };
    };
}
