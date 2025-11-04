{
  description = "NixOS configuration with Home Manager";

  inputs = {
    # Version pinning: These versions should match any infrastructure repos
    # that import tools from this dotfiles repository
    stable-nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    unstable-nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "stable-nixpkgs";
    hardware.url = "github:nixos/nixos-hardware";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "stable-nixpkgs";
    bip39-cli.url = "github:monomadic/bip39-cli";
    bip39-cli.flake = false;
  };

  outputs = inputs@{ self, stable-nixpkgs, unstable-nixpkgs, home-manager, sops-nix, nixos-generators, bip39-cli, ... }:
    let
      system = "x86_64-linux";

      # Consolidated package sets with consistent configuration
      unstable = import unstable-nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };


      stable = stable-nixpkgs.legacyPackages.${system};

      # Common specialArgs to reduce duplication
      commonSpecialArgs = {
        inherit inputs unstable;
      };

      mkHomeConfig = home-manager.lib.homeManagerConfiguration {
        pkgs = stable;
        extraSpecialArgs = commonSpecialArgs;
        modules = [ ./profiles/user.nix ];
      };
    in {
      nixosConfigurations = {
        slax = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = commonSpecialArgs;
          modules = [
            ./hosts/slax/configuration.nix
            # SOPS will be enabled manually after key setup
            sops-nix.nixosModules.sops
            ./modules/sops.nix
          ];
        };

        brix = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = commonSpecialArgs;
          modules = [
            ./hosts/brix/configuration.nix
            sops-nix.nixosModules.sops
            ./modules/sops.nix
          ];
        };

	snix = stable-nixpkgs.lib.nixosSystem {
	  inherit system;
	  specialArgs = commonSpecialArgs;
	  modules = [
	    ./hosts/snix/configuration.nix
            sops-nix.nixosModules.sops
	    ./modules/sops.nix
	  ];
	};

      };

      homeConfigurations = {
        "user@slax" = mkHomeConfig;
        "user@brix" = mkHomeConfig;
	"user@snix" = mkHomeConfig;
      };

      formatter.${system} = stable.nixpkgs-fmt;

      # Infrastructure tests
      checks.${system} = {};

      # ISO/VM image generation
      packages.${system} =
        let
          # Function to generate ISO/VM for any host
          mkImage = hostConfig: format: nixos-generators.nixosGenerate {
            inherit system format;
            specialArgs = commonSpecialArgs;
            modules = [ hostConfig ];
          };

          # Function to generate live ISO with SSH access
          mkLiveISO = hostConfig: nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              hostConfig
              sops-nix.nixosModules.sops
              ./modules/sops.nix
              ({ config, lib, ... }: {
                services.openssh.enable = true;
                # Disable graphical services for live ISO
              })
            ];
            format = "iso";
          };
        in {
          # Shared infrastructure tools (for other repos to import)
          # infrastructure-tools = import ./packages/infrastructure-tools.nix {
          #   pkgs = stable;
          #   lib = stable.lib;
          # };

          # Live ISOs for each host
          slax-live-iso = mkLiveISO ./hosts/slax/configuration.nix;
          brix-live-iso = mkLiveISO ./hosts/brix/configuration.nix;

          # VM images for each host
          slax-vm = mkImage ./hosts/slax/configuration.nix "vm";
          brix-vm = mkImage ./hosts/brix/configuration.nix "vm";

          # Alternative formats
          slax-qcow2 = mkImage ./hosts/slax/configuration.nix "qcow2";
          brix-qcow2 = mkImage ./hosts/brix/configuration.nix "qcow2";

          # Generic emergency recovery ISO
          emergency-iso = nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              ./hosts/common/base.nix
              sops-nix.nixosModules.sops
              ./modules/sops.nix
              ({ config, lib, ... }: {
                services.openssh.enable = true;
                users.users.root.openssh.authorizedKeys.keys =
                  lib.strings.splitString "\n" (lib.strings.removeSuffix "\n"
                    (builtins.readFile config.sops.secrets."ssh/emergencyKeys".path));
              })
            ];
            format = "iso";
          };
        };

      # Development shells
      devShells.${system} =
        let
          # Import infrastructure shells
          infraShells = import ./devshells/infrastructure.nix {
            pkgs = stable;
            lib = stable.lib;
          };

          # Import individual language shells directly
          rustShells = import ./devshells/rust.nix { pkgs = stable; };
          goShells = import ./devshells/go.nix { pkgs = stable; };
          pythonShells = import ./devshells/python.nix { pkgs = stable; };
        in {
          # Default dotfiles development shell (unchanged behavior)
          default = stable.mkShell {
            buildInputs = with stable; [
              nixpkgs-fmt
              sops
              age
              # Testing tools
              qemu
            ];

            shellHook = ''
              # Add scripts to PATH
              export PATH="$PWD/assets/scripts:$PATH"

              # Create convenient aliases
              alias check-versions="$PWD/assets/scripts/check-versions.sh"
              alias update-system="$PWD/assets/scripts/update-system.sh"
              alias update-home-manager="$PWD/assets/scripts/update-home-manager.sh"
              alias full-update="$PWD/assets/scripts/full-update.sh"

              echo "🧪 NixOS Infrastructure Development Environment"
              echo "Available commands:"
              echo "  nix flake check          - Run all tests"
              echo ""
              echo "System update scripts:"
              echo "  check-versions           - Check for upstream releases"
              echo "  update-system            - Update flake and rebuild NixOS"
              echo "  update-home-manager      - Update Home Manager configuration"
              echo "  full-update             - Run complete system update"
              echo ""
              echo "Build ISOs for specific hosts:"
              echo "  nix build .#slax-live-iso"
              echo "  nix build .#brix-live-iso"
              echo "  nix build .#emergency-iso"
              echo ""
              echo "Build VM images:"
              echo "  nix build .#slax-vm"
              echo "  nix build .#brix-vm"
              echo ""
              echo "Build QCOW2 images:"
              echo "  nix build .#slax-qcow2"
              echo "  nix build .#brix-qcow2"
              echo ""
              echo "Development shells available:"
              echo "  nix develop .#rust       - Rust development"
              echo "  nix develop .#go         - Go development"
              echo "  nix develop .#python     - Python development"
              echo "  nix develop .#languages  - Multi-language environment"
              echo "  nix develop .#infrastructure - Infrastructure tools"
              echo "  nix develop .#kubernetes - Kubernetes tools"
              echo "  nix develop .#security   - Security tools"
              echo ""
              echo "  sops secrets.yaml        - Edit secrets"
            '';
          };

          # Infrastructure development shells
          inherit (infraShells.devShells) infrastructure kubernetes security;

          # Programming language development shells
          inherit (rustShells.devShells) rust;
          inherit (goShells.devShells) go;
          inherit (pythonShells.devShells) python;
        };
    };
}
