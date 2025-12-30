{
  description = "NixOS configuration with Home Manager";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://microvm.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
    ];
  };

  # ==========================================================================
  # Credential Management
  # ==========================================================================
  # This flake uses a priority-based credential system to avoid hardcoded
  # passwords in version control:
  #
  # Priority (highest to lowest):
  #   1. SOPS secrets (for deployed systems with configured secrets)
  #   2. Environment variables at build time (for ISOs/VMs)
  #   3. No password (SSH key authentication required)
  #
  # Environment Variables:
  #   USER_PASSWORD_HASH     - Password hash for 'user' account (base.nix)
  #   NIXTV_PASSWORD_HASH    - Password hash for nixtv-player admin
  #   EMERGENCY_PASSWORD_HASH - Password hash for emergency ISO root
  #   EMERGENCY_SSH_KEY      - SSH public key for emergency ISO root
  #
  # Generate a password hash:
  #   nix-shell -p mkpasswd --run 'mkpasswd -m sha-512'
  #
  # Example builds:
  #   # Emergency ISO with password
  #   EMERGENCY_PASSWORD_HASH="$(mkpasswd -m sha-512)" nix build .#emergency-iso
  #
  #   # Emergency ISO with SSH key (more secure)
  #   EMERGENCY_SSH_KEY="ssh-ed25519 AAAA..." nix build .#emergency-iso
  #
  #   # nixtv-player ISO with admin password
  #   NIXTV_PASSWORD_HASH="$(mkpasswd -m sha-512)" nix build .#nixtv-player-iso
  #
  # For deployed systems, configure SOPS secrets instead (see docs/SOPS-SETUP.md)
  # ==========================================================================

  # ==========================================================================
  # Input Version Management
  # ==========================================================================
  # Versioning strategy:
  #   - stable-nixpkgs: Pin to latest stable NixOS release for production use
  #   - unstable-nixpkgs: Rolling release for cutting-edge packages
  #   - home-manager: Must match stable-nixpkgs version for compatibility
  #
  # Update commands:
  #   nix flake update                    # Update all inputs
  #   nix flake update stable-nixpkgs     # Update specific input
  #   nix flake lock --update-input sops-nix  # Alternative syntax
  #
  # Check for updates:
  #   nix flake metadata                  # Show current versions
  # ==========================================================================
  inputs = {
    # Core NixOS - pinned to stable release
    stable-nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Unstable channel for bleeding-edge packages
    unstable-nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager - version must match stable-nixpkgs for compatibility
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "stable-nixpkgs";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";

    # Image generation (ISOs, VMs)
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
      # Supported systems - easily extensible
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper to generate attrs for all systems
      forAllSystems = stable-nixpkgs.lib.genAttrs supportedSystems;

      # Per-system package sets
      pkgsFor = system: import stable-nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      unstablePkgsFor = system: import unstable-nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Common specialArgs factory (system-aware)
      mkSpecialArgs = system: {
        inherit inputs;
        inherit microvm rednix;
        unstable = unstablePkgsFor system;
      };

      # NixOS configuration builder - reduces duplication
      mkNixosConfig = { system ? "x86_64-linux", hostConfig, extraModules ? [] }:
        stable-nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = mkSpecialArgs system;
          modules = [
            hostConfig
            sops-nix.nixosModules.sops
            ./modules/sops.nix
            microvm.nixosModules.host
          ] ++ extraModules;
        };

      # Home-manager configuration builder with hostname support
      mkHomeConfig = {
        system ? "x86_64-linux",
        hostname,
        username ? "user",
        hostType ? "desktop",
        hostFeatures ? [ "development" "multimedia" ],
        extraModules ? []
      }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = (mkSpecialArgs system) // {
            inherit hostname username hostType hostFeatures;
            hostConfig = {};  # Placeholder for compatibility
          };
          modules = [ ./profiles/user.nix ] ++ extraModules;
        };
    in {
      nixosConfigurations = {
        slax = mkNixosConfig {
          hostConfig = ./hosts/slax/configuration.nix;
        };

        brix = mkNixosConfig {
          hostConfig = ./hosts/brix/configuration.nix;
        };

        snix = mkNixosConfig {
          hostConfig = ./hosts/snix/configuration.nix;
        };

        # nixtv-player is a dedicated appliance - no sops/microvm needed
        nixtv-player = mkNixosConfig {
          hostConfig = ./hosts/nixtv-player/configuration.nix;
          extraModules = [
            { microvm.host.enable = false; }  # Override microvm from mkNixosConfig
          ];
        };
      };

      homeConfigurations = {
        "user@slax" = mkHomeConfig {
          hostname = "slax";
          hostFeatures = [ "development" "multimedia" "gaming" ];
        };
        "user@brix" = mkHomeConfig {
          hostname = "brix";
          hostFeatures = [ "development" "multimedia" ];
        };
        "user@snix" = mkHomeConfig {
          hostname = "snix";
          hostFeatures = [ "development" "multimedia" "gaming" ];
        };
      };

      # Per-system outputs
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);

      # Flake checks - formatting validation
      checks = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          formatting = pkgs.runCommand "check-formatting" {
            buildInputs = [ pkgs.nixfmt-rfc-style pkgs.findutils ];
          } ''
            cd ${self}
            # Check all nix files for formatting compliance
            find . -name "*.nix" -type f -print0 | xargs -0 nixfmt --check || {
              echo "Formatting issues found. Run 'nix fmt' to fix."
              exit 1
            }
            touch $out
          '';

          shellcheck = pkgs.runCommand "check-shellscripts" {
            buildInputs = [ pkgs.shellcheck pkgs.findutils ];
          } ''
            cd ${self}
            # Check all shell scripts for common issues
            find assets/scripts -name "*.sh" -type f -print0 | xargs -0 shellcheck --severity=warning || {
              echo "Shell script issues found. Fix the issues above."
              exit 1
            }
            touch $out
          '';

          yaml-syntax = pkgs.runCommand "check-yaml-syntax" {
            buildInputs = [ pkgs.yq-go pkgs.findutils ];
          } ''
            cd ${self}
            # Validate YAML syntax in docker-compose and config files
            for f in $(find hosts/wintv -name "*.yml" -o -name "*.yaml" 2>/dev/null); do
              yq eval '.' "$f" > /dev/null || {
                echo "YAML syntax error in: $f"
                exit 1
              }
            done
            touch $out
          '';
        });

      # ISO/VM image generation and wintv config
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;

          # WinTV declarative configuration generators
          wintvGenerators = import ./lib/wintv-generators.nix {
            lib = pkgs.lib;
            inherit pkgs;
          };

          # WinTV configuration (imports the config.nix)
          wintvConfig = (import ./hosts/wintv/config.nix { lib = pkgs.lib; }).wintv;

          # Function to generate ISO/VM for any host
          mkImage = hostConfig: format: nixos-generators.nixosGenerate {
            inherit system format;
            specialArgs = mkSpecialArgs system;
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
            specialArgs = mkSpecialArgs system;
            modules = [
              hostConfig
              sops-nix.nixosModules.sops
              ./modules/sops.nix
              microvm.nixosModules.host
              ({ config, lib, ... }: {
                services.openssh.enable = true;
              })
            ];
            format = "iso";
          };
        in {
          # =======================================================================
          # WinTV - Declarative Windows + Podman configuration
          # =======================================================================
          # Build: nix build .#wintv-config
          # Deploy: Copy result/ to Windows and run .\deploy.ps1 -Apply
          wintv-config = wintvGenerators.buildWintvConfig wintvConfig;

          # Live ISOs for each host
          slax-live-iso = mkLiveISO ./hosts/slax/configuration.nix;
          brix-live-iso = mkLiveISO ./hosts/brix/configuration.nix;

          nixtv-player-iso = nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = mkSpecialArgs system;
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

          nixtv-player-vm = (stable-nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = mkSpecialArgs system;
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
          # =======================================================================
          # Build with custom credentials (recommended):
          #   EMERGENCY_SSH_KEY="ssh-ed25519 AAAA..." nix build .#emergency-iso
          #   EMERGENCY_PASSWORD_HASH="$(mkpasswd -m sha-512)" nix build .#emergency-iso
          #
          # Without env vars: SSH enabled, no password (SSH key required)
          # =======================================================================
          emergency-iso = nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = mkSpecialArgs system;
            modules = [
              ./hosts/common/base.nix
              sops-nix.nixosModules.sops
              ./modules/sops.nix
              microvm.nixosModules.host
              ({ config, lib, pkgs, ... }:
                let
                  envKey = builtins.getEnv "EMERGENCY_SSH_KEY";
                  envPasswordHash = builtins.getEnv "EMERGENCY_PASSWORD_HASH";
                  # Validate SSH key format (must start with valid key type)
                  validSshKeyPrefixes = [ "ssh-ed25519" "ssh-rsa" "ssh-ecdsa" "ecdsa-sha2-" "sk-ssh-ed25519" "sk-ecdsa-sha2-" ];
                  isValidSshKey = key: key == "" || lib.any (prefix: lib.hasPrefix prefix key) validSshKeyPrefixes;
                  sshKeyValid = isValidSshKey envKey;
                in {
                  # Assert SSH key format is valid if provided
                  assertions = [{
                    assertion = sshKeyValid;
                    message = "EMERGENCY_SSH_KEY has invalid format. Must start with: ${lib.concatStringsSep ", " validSshKeyPrefixes}";
                  }];
                  services.openssh = {
                    enable = true;
                    settings.PermitRootLogin = if envKey != "" then "prohibit-password" else "yes";
                  };
                  users.users.root = {
                    openssh.authorizedKeys.keys = lib.optional (envKey != "" && sshKeyValid) envKey;
                    # Use env var hash if provided, otherwise no password (SSH key required)
                    initialHashedPassword = lib.mkIf (envPasswordHash != "") envPasswordHash;
                  };
                  environment.etc."motd".text = ''
                    ════════════════════════════════════════════════════════════════
                      EMERGENCY RECOVERY ISO
                    ${lib.optionalString (envPasswordHash != "") "  Password was set at build time - change with: passwd"}
                    ${lib.optionalString (envKey != "") "  SSH key configured - password login disabled"}
                    ${lib.optionalString (envKey == "" && envPasswordHash == "") "  WARNING: No credentials configured! Add SSH key or rebuild with password."}
                    ════════════════════════════════════════════════════════════════
                  '';
                })
            ];
            format = "iso";
          };
        });

      # Development shells
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;

          # Import infrastructure shells
          infraShells = import ./devshells/infrastructure.nix {
            inherit pkgs;
            lib = pkgs.lib;
          };

          # Import individual language shells directly
          rustShells = import ./devshells/rust.nix { inherit pkgs; };
          goShells = import ./devshells/go.nix { inherit pkgs; };
          pythonShells = import ./devshells/python.nix { inherit pkgs; };
        in {
          # Default dotfiles development shell
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixfmt-rfc-style
              sops
              age
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

              echo "NixOS Infrastructure Development Environment"
              echo ""
              echo "Commands:"
              echo "  nix flake check          - Run all tests"
              echo "  nix fmt                  - Format all nix files"
              echo ""
              echo "System update scripts:"
              echo "  check-versions           - Check for upstream releases"
              echo "  update-system            - Update flake and rebuild NixOS"
              echo "  update-home-manager      - Update Home Manager configuration"
              echo "  full-update              - Run complete system update"
              echo ""
              echo "Build ISOs/VMs:"
              echo "  nix build .#slax-live-iso / .#brix-live-iso / .#emergency-iso"
              echo "  nix build .#slax-vm / .#brix-vm"
              echo ""
              echo "Dev shells: .#rust .#go .#python .#infrastructure .#kubernetes .#security"
            '';
          };

          # Infrastructure development shells
          inherit (infraShells.devShells) infrastructure kubernetes security;

          # Programming language development shells
          inherit (rustShells.devShells) rust;
          inherit (goShells.devShells) go;
          inherit (pythonShells.devShells) python;
        });
    };
}
