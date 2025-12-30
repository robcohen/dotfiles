# Architecture Guide

This document explains the design decisions and structure of this NixOS configuration.

## Design Philosophy

1. **Declarative Everything**: All configuration is in Nix, including disk partitioning (Disko)
2. **Modular Composition**: Small, focused modules composed into complete systems
3. **Security by Default**: Hardware-backed secrets, encrypted storage, hardened systems
4. **Reproducibility**: Any host can be rebuilt identically from this repository
5. **Cross-Platform**: Support for NixOS, Home Manager standalone, and Windows (WinTV)

## Flake Structure

```
flake.nix                          # Entry point (~125 lines with flake-parts)
├── inputs                         # External dependencies
│   ├── stable-nixpkgs            # NixOS 25.11 (primary)
│   ├── unstable-nixpkgs          # Rolling release for cutting-edge packages
│   ├── home-manager              # User environment management
│   ├── sops-nix                  # Secrets management
│   ├── disko                     # Declarative disk partitioning
│   ├── microvm                   # Lightweight VMs for security testing
│   ├── flake-parts               # Modular flake organization
│   └── nixos-generators          # ISO/VM image generation
└── outputs                        # Via flake-parts modules
```

## Directory Layout

```
.
├── flake.nix                      # Flake entry point
├── flake-parts/                   # Flake-parts modules
│   ├── systems.nix               # Supported systems (x86_64, aarch64)
│   ├── module-args.nix           # Shared arguments
│   ├── per-system/               # Per-architecture outputs
│   │   ├── formatter.nix         # nixfmt-rfc-style
│   │   ├── checks.nix            # Flake checks
│   │   ├── dev-shells.nix        # Development environments
│   │   └── packages.nix          # ISOs, VMs, wintv-config
│   └── outputs/                   # Top-level outputs
│       ├── nixos.nix             # nixosConfigurations
│       └── home-manager.nix      # homeConfigurations
├── lib/                           # Shared helper functions
│   ├── constants.nix             # Host definitions, defaults
│   ├── system-builders.nix       # mkNixosConfig, pkgsFor
│   ├── home-builders.nix         # mkHomeConfig
│   └── wintv-generators.nix      # Windows config generators
├── hosts/                         # Host-specific configurations
│   ├── common/                   # Shared across all hosts
│   │   ├── base.nix              # Core NixOS settings
│   │   ├── security.nix          # Security hardening
│   │   ├── tpm.nix               # TPM configuration
│   │   ├── sddm.nix              # Display manager
│   │   └── swap.nix              # Swap configuration
│   ├── slax/                     # Desktop workstation
│   ├── brix/                     # Mini PC (gaming/media)
│   ├── snix/                     # AMD laptop
│   ├── nixtv-player/             # Media player appliance
│   └── wintv/                    # Windows media server (Podman)
├── profiles/                      # Reusable profile modules
│   ├── desktop/                  # Desktop environments
│   ├── features/                 # Feature toggles
│   ├── programs/                 # Application configs
│   ├── security/                 # Security profiles
│   └── services/                 # System services
├── modules/                       # Custom NixOS modules
│   ├── default.nix               # Module exports index
│   ├── sops.nix                  # SOPS integration
│   ├── virtualization.nix        # VM/container support
│   ├── arr-stack.nix             # Media automation
│   └── travel-router.nix         # Portable AP mode
├── devshells/                     # Development environments
│   ├── default.nix               # Default shell
│   ├── infrastructure.nix        # K8s/Terraform tools
│   ├── rust.nix                  # Rust development
│   └── ...                       # Language-specific shells
└── docs/                          # Documentation
```

## Key Patterns

### 1. Configuration Builders (lib/)

The `lib/system-builders.nix` provides factories that reduce duplication:

```nix
mkNixosConfig = { system, hostConfig, extraModules ? [] }:
  nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = mkSpecialArgs system;  # unstable, inputs, disko, etc.
    modules = [
      hostConfig
      sops-nix.nixosModules.sops    # Always included
      microvm.nixosModules.host      # Always included
    ] ++ extraModules;
  };
```

### 2. Host Organization

Each host has a dedicated directory:

```
hosts/snix/
├── configuration.nix       # Main config, imports modules
├── hardware-configuration.nix  # Generated hardware detection
└── disko.nix              # Declarative disk layout
```

Hosts import from `common/` for shared settings and `modules/` for features.

### 3. Profile Composition

Profiles are atomic configuration units that can be mixed:

```nix
# profiles/programs/git.nix
{ config, lib, ... }: {
  programs.git = {
    enable = true;
    # ... configuration
  };
}
```

Home configurations compose profiles based on host features:

```nix
imports = [
  ./programs/git.nix
  ./programs/zsh.nix
] ++ lib.optionals (hasFeature "development") [
  ./features/development.nix
];
```

### 4. Feature Flags

Hosts declare features that affect both NixOS and Home Manager:

```nix
# lib/constants.nix
hosts = {
  snix = {
    system = "x86_64-linux";
    hostType = "laptop";
    hostFeatures = [ "development" "multimedia" "security" ];
  };
};
```

### 5. Secrets Management (SOPS)

Secrets flow through a priority system:

1. **SOPS secrets** (deployed systems with `~/.secrets/secrets.yaml`)
2. **Environment variables** (build-time for ISOs/VMs)
3. **No credentials** (SSH key authentication only)

```nix
# Pattern used in configurations
users.users.myuser = {
  hashedPasswordFile = lib.mkIf hasSopsPassword
    config.sops.secrets."user/hashedPassword".path;
  initialHashedPassword = lib.mkIf (!hasSopsPassword && envHash != "") # noqa: secret
    envHash;
};
```

### 6. Disko Integration

Disko provides declarative disk partitioning:

```nix
# hosts/snix/disko.nix
disko.devices.disk.main = {
  device = "/dev/nvme0n1";
  content.type = "gpt";
  partitions = {
    ESP = { size = "1G"; content.type = "filesystem"; };
    root = {
      content.type = "luks";
      content.content.type = "btrfs";
      # subvolumes...
    };
  };
};
```

For existing systems, disko.nix documents the intended layout without modifying disks.

### 7. Module Exports

Custom modules are exported for potential reuse:

```nix
# modules/default.nix
{
  nixosModules = {
    sops = ./sops.nix;
    virtualization = ./virtualization.nix;
    arr-stack = ./arr-stack.nix;
    # ...
  };
}
```

## Data Flow

```
flake.nix (inputs)
    │
    ▼
flake-parts/module-args.nix (specialArgs: unstable, inputs, disko)
    │
    ├──► lib/system-builders.nix ──► nixosConfigurations
    │        │
    │        ├── hosts/*/configuration.nix
    │        ├── hosts/common/*.nix
    │        ├── modules/*.nix
    │        └── sops-nix, microvm (auto-included)
    │
    └──► lib/home-builders.nix ──► homeConfigurations
             │
             ├── profiles/programs/*.nix
             ├── profiles/features/*.nix
             └── profiles/desktop/*.nix
```

## Unique Features

### TPM/BIP39 Security

Hardware-backed key derivation from a 24-word mnemonic:

- Keys never exist unencrypted outside TPM
- Deterministic recovery on any TPM device
- Used for SSH keys, SOPS encryption, signing

### Windows Support (WinTV)

Declarative Windows configuration via Nix-generated PowerShell:

```nix
# modules/wintv.nix generates:
# - docker-compose.yml
# - PowerShell setup scripts
# - Service configurations
```

### Travel Router

Converts NixOS laptop into a WiFi hotspot with VPN:

```nix
travelRouter = {
  enable = true;
  apInterface = "wlan0";
  webUI.enable = true;  # Management interface
};
```

## Extension Points

### Adding a New Host

1. Create `hosts/newhost/configuration.nix`
2. Generate `hardware-configuration.nix`
3. Create `disko.nix` for disk layout
4. Add to `lib/constants.nix`:
   ```nix
   newhost = {
     system = "x86_64-linux";
     hostFeatures = [ "development" ];
   };
   ```
5. Entry is auto-discovered by `flake-parts/outputs/nixos.nix`

### Adding a New Module

1. Create `modules/mymodule.nix` with options
2. Export in `modules/default.nix`
3. Import in host configurations as needed

### Adding a New Program Profile

1. Create `profiles/programs/myapp.nix`
2. Import in home configurations

## Future Architecture Plans

- **Impermanence**: Ephemeral root with opt-in persistence (`/persist`)
- **Lanzaboote**: Secure Boot with signed UKIs
- **CI/CD**: Self-hosted Hydra or Forgejo Actions
- **Remote Builders**: Distributed builds across hosts
