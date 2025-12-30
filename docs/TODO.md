# Improvement Roadmap

Areas for improvement based on best practices from top NixOS configurations.

## Critical Priority

### Self-Hosted CI/CD Pipeline

**Status**: Not implemented

**Why**: Catches configuration errors before deployment, enables automated testing, provides binary caching.

**Options**:
- **Hydra** - Official Nix CI, complex setup
- **Forgejo Actions** - GitHub Actions compatible, self-hosted
- **Buildbot** - Flexible, Nix-native support

**Implementation**:
```yaml
# .forgejo/workflows/check.yml
jobs:
  check:
    runs-on: nix
    steps:
      - uses: actions/checkout@v4
      - run: nix flake check
      - run: nix build .#nixosConfigurations.snix.config.system.build.toplevel
```

**Tasks**:
- [ ] Set up Forgejo or Gitea instance
- [ ] Configure Forgejo Actions runner with Nix
- [ ] Create workflow for `nix flake check`
- [ ] Create workflow for building all hosts
- [ ] Set up Cachix or Attic for binary caching
- [ ] Add build status badges to README

---

### Secure Boot (Lanzaboote)

**Status**: Not implemented

**Why**: Prevents boot-level tampering, required for full disk encryption security chain.

**Implementation**:
```nix
# flake.nix
inputs.lanzaboote.url = "github:nix-community/lanzaboote";

# hosts/snix/configuration.nix
boot.loader.systemd-boot.enable = lib.mkForce false;
boot.lanzaboote = {
  enable = true;
  pkiBundle = "/etc/secureboot";
};
```

**Tasks**:
- [ ] Add lanzaboote input to flake.nix
- [ ] Generate Secure Boot keys with `sbctl`
- [ ] Enroll keys in firmware
- [ ] Configure lanzaboote for each host
- [ ] Test boot with Secure Boot enabled
- [ ] Document key backup/recovery process

---

## High Priority

### Impermanence (Ephemeral Root)

**Status**: Not implemented (infrastructure prepared in disko.nix)

**Why**: Clean system state on every boot, forces explicit persistence, reduces cruft.

**Implementation**:
```nix
# flake.nix
inputs.impermanence.url = "github:nix-community/impermanence";

# hosts/snix/configuration.nix
environment.persistence."/persist" = {
  hideMounts = true;
  directories = [
    "/var/log"
    "/var/lib/nixos"
    "/var/lib/systemd"
    "/etc/NetworkManager/system-connections"
  ];
  files = [
    "/etc/machine-id"
  ];
  users.user = {
    directories = [
      "Documents"
      "Projects"
      ".ssh"
      ".gnupg"
    ];
  };
};
```

**Tasks**:
- [ ] Add impermanence input to flake.nix
- [ ] Audit current system for required persistent paths
- [ ] Configure `/persist` subvolume (already in disko.nix)
- [ ] Add impermanence module to hosts
- [ ] Test with rollback to empty root
- [ ] Document what persists and why

---

### Disko for Remaining Hosts

**Status**: Only snix has disko configuration

**Tasks**:
- [ ] Create `hosts/slax/disko.nix`
- [ ] Create `hosts/brix/disko.nix`
- [ ] Create `hosts/nixtv-player/disko.nix`
- [ ] Document disk layout differences per host
- [ ] Test fresh installs with disko

---

### Personal Binary Cache

**Status**: Using community caches only

**Why**: Faster rebuilds, share builds across machines, required for CI/CD.

**Options**:
- **Cachix** - Hosted, easy setup, free tier available
- **Attic** - Self-hosted, S3-compatible storage
- **nix-serve** - Simple, single-machine

**Tasks**:
- [ ] Choose caching solution
- [ ] Set up cache (Attic on homelab or Cachix)
- [ ] Add cache to flake.nix nixConfig
- [ ] Configure CI to push builds to cache
- [ ] Document cache usage

---

## Medium Priority

### nix-darwin Support (macOS)

**Status**: Not implemented

**Why**: Unified configuration across Linux and macOS machines.

**Implementation**:
```nix
# flake.nix
inputs.darwin.url = "github:lnl7/nix-darwin";
inputs.darwin.inputs.nixpkgs.follows = "stable-nixpkgs";

# Add to outputs
darwinConfigurations.macbook = darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [ ./hosts/macbook/configuration.nix ];
};
```

**Tasks**:
- [ ] Add nix-darwin input
- [ ] Create darwin host configuration
- [ ] Share common profiles between Linux/Darwin
- [ ] Test Home Manager on Darwin
- [ ] Document Darwin-specific setup

---

### Automated Testing

**Status**: Only pre-commit hooks

**Why**: Catch regressions, validate configurations work as expected.

**Options**:
- NixOS VM tests (`nixosTest`)
- Integration tests for services
- Snapshot testing for generated configs

**Tasks**:
- [ ] Add nixosTest for critical services
- [ ] Test SOPS secret decryption
- [ ] Test network configuration
- [ ] Add to CI pipeline

---

### Remote Builders

**Status**: Not configured

**Why**: Distribute builds across machines, faster builds on powerful hardware.

**Tasks**:
- [ ] Configure builder keys
- [ ] Set up nix.buildMachines on hosts
- [ ] Document builder setup
- [ ] Test distributed builds

---

### Secrets Rotation

**Status**: Manual process

**Why**: Security hygiene, limit blast radius of compromised keys.

**Tasks**:
- [ ] Document rotation procedure
- [ ] Create rotation script
- [ ] Set up rotation reminders
- [ ] Test recovery from backup mnemonic

---

## Low Priority

### Flake Templates

**Status**: Not implemented

**Why**: Easy onboarding for new hosts/projects.

**Tasks**:
- [ ] Create `flake.templates.default` for new hosts
- [ ] Create devshell templates
- [ ] Document template usage

---

### Module Documentation

**Status**: Inline comments only

**Why**: Discoverability, easier contribution.

**Tasks**:
- [ ] Add NixOS option descriptions
- [ ] Generate documentation from options
- [ ] Add examples to module comments

---

### Declarative Disk Encryption Key Management

**Status**: Manual LUKS passphrase

**Options**:
- TPM2 auto-unlock with `systemd-cryptenroll`
- FIDO2 key unlock
- Network-bound encryption (Tang/Clevis)

**Tasks**:
- [ ] Evaluate TPM unlock security tradeoffs
- [ ] Configure systemd-cryptenroll for TPM
- [ ] Document recovery procedures
- [ ] Test with TPM clear scenarios

---

### Home Manager Standalone Mode

**Status**: Only NixOS-integrated

**Why**: Use on non-NixOS systems, servers, containers.

**Tasks**:
- [ ] Test standalone Home Manager activation
- [ ] Document standalone usage
- [ ] Create minimal home-only configuration

---

### Monitoring & Alerting

**Status**: Basic (smartd, vnstat)

**Why**: Proactive issue detection, system health visibility.

**Options**:
- Prometheus + Grafana
- Netdata
- Simple scripts with ntfy.sh

**Tasks**:
- [ ] Choose monitoring stack
- [ ] Configure metrics collection
- [ ] Set up alerting (disk, memory, services)
- [ ] Create dashboards

---

## Completed

- [x] Migrate to flake-parts
- [x] Disko configuration for snix
- [x] Documentation (INSTALLATION, ARCHITECTURE, TROUBLESHOOTING)
- [x] Pre-commit hooks for secrets scanning
- [x] SOPS secrets management
- [x] TPM/BIP39 key derivation
- [x] Module exports in modules/default.nix

---

## Comparison to Top Repos

| Feature | This Repo | ryan4yin | Misterio77 | fufexan |
|---------|-----------|----------|------------|---------|
| flake-parts | ✅ | ❌ | ❌ | ✅ |
| Disko | ✅ (snix) | ✅ | ✅ | ❌ |
| Lanzaboote | ❌ | ✅ | ✅ | ❌ |
| Impermanence | ❌ | ✅ | ✅ | ❌ |
| CI/CD | ❌ | ✅ | ✅ | ✅ |
| Binary Cache | ❌ | ✅ | ✅ | ✅ |
| nix-darwin | ❌ | ✅ | ❌ | ❌ |
| TPM/BIP39 | ✅ | ❌ | ❌ | ❌ |
| Windows Support | ✅ | ❌ | ❌ | ❌ |
| Module Exports | ✅ | ✅ | ✅ | ✅ |

**Unique strengths**: TPM/BIP39 security, Windows/WinTV support, flake-parts adoption
**Key gaps**: CI/CD, Secure Boot, Impermanence, Binary Cache
