{
  description = "NixOS configuration with Home Manager";

  inputs = {
    # Version pinning: These versions should match any infrastructure repos
    # that import tools from this dotfiles repository
    stable-nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    unstable-nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "stable-nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "stable-nixpkgs";

    # MicroVMs for ephemeral security testing
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "stable-nixpkgs";
    rednix.url = "github:redcode-labs/RedNix";
    rednix.inputs.nixpkgs.follows = "unstable-nixpkgs";
  };

  outputs = inputs@{ self, stable-nixpkgs, unstable-nixpkgs, home-manager, sops-nix, nixos-generators, microvm, rednix, ... }:
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
        inherit microvm rednix;
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
            sops-nix.nixosModules.sops
            ./modules/sops.nix
            microvm.nixosModules.host
          ];
        };

        brix = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = commonSpecialArgs;
          modules = [
            ./hosts/brix/configuration.nix
            sops-nix.nixosModules.sops
            ./modules/sops.nix
            microvm.nixosModules.host
          ];
        };

        snix = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = commonSpecialArgs;
          modules = [
            ./hosts/snix/configuration.nix
            sops-nix.nixosModules.sops
            ./modules/sops.nix
            microvm.nixosModules.host
          ];
        };

        nixtv-server = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = commonSpecialArgs;
          modules = [
            ./hosts/nixtv-server/configuration.nix
            # No sops for dedicated HTPC appliance
            # No microvm for HTPC
          ];
        };

        nixtv-player = stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = commonSpecialArgs;
          modules = [
            ./hosts/nixtv-player/configuration.nix
          ];
        };

      };

      homeConfigurations = {
        "user@slax" = mkHomeConfig;
        "user@brix" = mkHomeConfig;
	"user@snix" = mkHomeConfig;
      };

      formatter.${system} = stable.nixfmt;

      # Infrastructure tests
      checks.${system} = {};

      # ISO/VM image generation
      packages.${system} =
        let
          # Function to generate ISO/VM for any host
          mkImage = hostConfig: format: nixos-generators.nixosGenerate {
            inherit system format;
            specialArgs = commonSpecialArgs;
            modules = [
              hostConfig
              sops-nix.nixosModules.sops
              ./modules/sops.nix
              microvm.nixosModules.host
            ];
          };

          # Function to generate live ISO with SSH access
          mkLiveISO = hostConfig: nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              hostConfig
              sops-nix.nixosModules.sops
              ./modules/sops.nix
              microvm.nixosModules.host
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
          nixtv-server-iso = nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              ./hosts/nixtv-server/configuration.nix
              ({ lib, ... }: {
                # ISO-specific overrides
                services.cage.enable = lib.mkForce false;
                services.displayManager.autoLogin.enable = lib.mkForce false;
                boot.loader.timeout = lib.mkForce 10;
              })
            ];
            format = "iso";
          };

          nixtv-player-iso = nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              ./hosts/nixtv-player/configuration.nix
              ({ lib, ... }: {
                services.cage.enable = lib.mkForce false;
                services.displayManager.autoLogin.enable = lib.mkForce false;
                boot.loader.timeout = lib.mkForce 10;
              })
            ];
            format = "iso";
          };

          # VM images for each host
          slax-vm = mkImage ./hosts/slax/configuration.nix "vm";
          brix-vm = mkImage ./hosts/brix/configuration.nix "vm";
          nixtv-server-vm = (stable-nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              "${stable-nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
              ./hosts/nixtv-server/configuration.nix
              ({ lib, pkgs, ... }: {
                virtualisation = {
                  memorySize = 4096;
                  cores = 4;
                  graphics = true;
                };
                # Use X11 Kodi in VM for easier testing
                services.cage.enable = lib.mkForce false;
                services.xserver = {
                  enable = true;
                  desktopManager.kodi.enable = true;
                  displayManager.lightdm.enable = true;
                };
              })
            ];
          }).config.system.build.vm;

          nixtv-player-vm = (stable-nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              "${stable-nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
              ./hosts/nixtv-player/configuration.nix
              ({ lib, pkgs, ... }: {
                virtualisation = {
                  memorySize = 2048;
                  cores = 2;
                  graphics = true;
                };
                services.cage.enable = lib.mkForce false;
                services.xserver = {
                  enable = true;
                  desktopManager.kodi.enable = true;
                  displayManager.lightdm.enable = true;
                };
              })
            ];
          }).config.system.build.vm;

          # Generic emergency recovery ISO
          # Note: For SSH access, add your public key to authorized_keys after boot
          # or set EMERGENCY_SSH_KEY environment variable before building
          emergency-iso = nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = commonSpecialArgs;
            modules = [
              ./hosts/common/base.nix
              sops-nix.nixosModules.sops
              ./modules/sops.nix
              microvm.nixosModules.host
              ({ config, lib, pkgs, ... }:
                let
                  # Allow setting SSH key via environment variable for builds
                  envKey = builtins.getEnv "EMERGENCY_SSH_KEY";
                in {
                  services.openssh = {
                    enable = true;
                    settings.PermitRootLogin = "yes";
                  };
                  # Use env key if provided, otherwise allow password auth temporarily
                  users.users.root = {
                    openssh.authorizedKeys.keys = lib.optional (envKey != "") envKey;
                    # Temporary initial password - change immediately after boot
                    hashedInitialPassword = "$6$oRekJppvDJ4Guceg$xcOjqHPI5bmpZ8EOb1yytjpwUSEiLnNKpjIdDM4.jPoMUdOXozjabyqhky8xJy3snn.fh3Ra7.GiJAg4GSbVg/";
                  };
                  # Warning message on login
                  environment.etc."motd".text = ''
                    ╔══════════════════════════════════════════════════════════════╗
                    ║  EMERGENCY RECOVERY ISO                                       ║
                    ║  Change the root password immediately: passwd                 ║
                    ║  Add your SSH key: ssh-copy-id root@<this-host>              ║
                    ╚══════════════════════════════════════════════════════════════╝
                  '';
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
              nixfmt
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
