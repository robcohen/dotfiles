{
  description = "Rob Cohen nix config";

  inputs = {
    stable-nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    unstable-nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "stable-nixpkgs";
    hardware.url = "github:nixos/nixos-hardware";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
  };

  outputs = inputs@{ self, stable-nixpkgs, unstable-nixpkgs, home-manager, sops-nix, nixos-cosmic, ... }:
    let
      system = "x86_64-linux";

      cosmic = import unstable-nixpkgs {
        inherit system;
        overlays = [ nixos-cosmic.overlays.default ];
      };

      unstable = import inputs.unstable-nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkHomeConfig = home-manager.lib.homeManagerConfiguration {
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
            nixos-cosmic.nixosModules.default
            ./hosts/slax/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };

        brix = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            unstable = cosmic;
          };
          modules = [
            nixos-cosmic.nixosModules.default
            ./hosts/brix/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };

        server-river = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            unstable = stable-nixpkgs.legacyPackages.${system};
          };
          modules = [
            ./hosts/server-river/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };
      };

      homeConfigurations = {
        "user@slax" = mkHomeConfig;
        "user@brix" = mkHomeConfig;
        "user@server-river" = mkHomeConfig;
      };

      formatter.${system} = stable-nixpkgs.legacyPackages.${system}.nixpkgs-fmt;

      # Infrastructure tests
      checks.${system} = {
        server-river-test = import ./tests/server-river-test.nix {
          inherit system;
          pkgs = stable-nixpkgs.legacyPackages.${system};
        };
      };

      # Development shell with testing tools
      devShells.${system}.default = stable-nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with stable-nixpkgs.legacyPackages.${system}; [
          nixpkgs-fmt
          sops
          age
          # Testing tools
          nixos-test-driver
        ];
        
        shellHook = ''
          echo "🧪 NixOS Infrastructure Development Environment"
          echo "Available commands:"
          echo "  nix flake check          - Run all tests"
          echo "  nix build .#checks.x86_64-linux.server-river-test  - Run specific test"
          echo "  sops secrets.yaml        - Edit secrets"
        '';
      };
    };
}
