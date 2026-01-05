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

    # Flake-parts for modular flake structure
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "stable-nixpkgs";

    # Disko for declarative disk partitioning
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "stable-nixpkgs";

    # Private infrastructure configs (network, Tailscale, router)
    infra-private = {
      url = "git+ssh://git@github.com/robcohen/infra-private";
      flake = true;
    };

    # AMD NPU support (Ryzen AI)
    nix-amd-npu.url = "github:robcohen/nix-amd-npu";
    nix-amd-npu.inputs.nixpkgs.follows = "unstable-nixpkgs";
  };

  # ==========================================================================
  # Flake Outputs (via flake-parts)
  # ==========================================================================
  # Structure:
  #   flake-parts/systems.nix      - Supported systems (x86_64-linux, aarch64-linux)
  #   flake-parts/module-args.nix  - Shared args (builders, constants)
  #   flake-parts/per-system/      - Per-system outputs (formatter, checks, etc.)
  #   flake-parts/outputs/         - Top-level outputs (nixosConfigurations, etc.)
  #   lib/                         - Helper functions (system-builders, etc.)
  # ==========================================================================
  outputs =
    inputs@{ flake-parts, home-manager, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # External flake-parts modules
        home-manager.flakeModules.home-manager

        # Core configuration
        ./flake-parts/systems.nix
        ./flake-parts/module-args.nix

        # Per-system outputs
        ./flake-parts/per-system/formatter.nix
        ./flake-parts/per-system/checks.nix
        ./flake-parts/per-system/dev-shells.nix
        ./flake-parts/per-system/packages.nix

        # Top-level outputs
        ./flake-parts/outputs/nixos.nix
        ./flake-parts/outputs/home-manager.nix
        ./flake-parts/outputs/exports.nix
      ];
    };
}
