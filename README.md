# NixOS Configuration with Home Manager

A comprehensive NixOS configuration using flakes and Home Manager, featuring desktop environments, development tools, and security configurations.

## 🚀 Quick Start

### Prerequisites
- NixOS with flakes enabled
- Git

### Setup
1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Configure personal settings:**
   ```bash
   cp secrets.example.nix secrets.nix
   # Edit secrets.nix with your personal information

   # Set up secure private secrets directory
   mkdir -p ~/.secrets
   chmod 700 ~/.secrets
   ```

3. **Apply configuration:**
   ```bash
   # For desktop hosts (slax/brix)
   sudo nixos-rebuild switch --flake .#slax

   # Apply home-manager configuration
   home-manager switch --flake .#user@slax
   ```

4. **Bootstrap secrets (after system builds successfully):**
   ```bash
   # Generate new BIP39 mnemonic and set up SOPS
   ./assets/scripts/bootstrap-secrets.sh --generate

   # Or use existing mnemonic
   ./assets/scripts/bootstrap-secrets.sh --mnemonic "your 24 words here"
   ```

## 📁 Repository Structure

```
├── flake.nix              # Main flake configuration
├── hosts/                 # Host-specific configurations
│   ├── slax/              # Desktop configuration
│   ├── brix/              # Mini PC configuration
│   └── common/            # Shared host configurations
├── profiles/              # Modular configuration profiles
│   ├── desktop/           # Desktop environment configs
│   ├── features/          # Feature modules (gaming, development, etc.)
│   ├── programs/          # Program-specific configurations
│   ├── security/          # Security hardening configurations
│   └── services/          # System services
├── lib/                   # Shared libraries and variables
├── assets/                # Static assets (wallpapers, configs)
├── secrets.example.nix    # Template for personal secrets
└── README.md              # This file
```

## 🏠 Available Hosts

- **slax**: Desktop configuration with development and multimedia features
- **brix**: Mini PC configuration with gaming, development, and multimedia features

## ⚙️ Features

### Desktop Environment
- **COSMIC Desktop**: Modern desktop environment
- **Customized themes**: Dark themes and consistent styling
- **Font configuration**: Programming and UI fonts

### Development Tools
- **Languages**: Support for multiple programming languages
- **Editors**: Configured development environments
- **Shell**: Enhanced Zsh with Starship prompt
- **Git**: Comprehensive Git configuration with SSH signing
- **Infrastructure**: Kubernetes, Terraform, and infrastructure management tools
- **Auto-environment**: Direnv automatically loads project-specific tools

### Security Features
- **GPG/SSH**: Advanced cryptographic configurations
- **BIP39/TPM**: Hardware-backed key derivation from mnemonic phrases
- **System hardening**: Security-focused system configurations
- **Secure boot**: TPM and secure boot configurations

### Multimedia
- **Audio/Video**: Complete multimedia stack
- **Gaming**: Steam and gaming optimizations (brix host)

## 🔧 Customization

### Personal Information
Edit `secrets.nix` to customize:
- User information (name, email, GitHub username)
- Domain names (for infrastructure integration)
- SSH keys and signing keys

### Infrastructure Integration
The configuration includes tools for infrastructure management:
- **VPN**: Tailscale client for secure infrastructure access
- **Kubernetes**: kubectl, helm, k9s for cluster management
- **Infrastructure as Code**: Terraform and OpenTofu
- **Auto-loading**: Direnv automatically provides tools in project directories

To use with your infrastructure:
1. Clone your infrastructure repo to `~/Projects/your-infrastructure`
2. The environment will auto-configure with appropriate tools
3. Connect via VPN to access internal services

### Host Features
Modify host configurations in `hosts/` to enable/disable features:
```nix
features = [ "gaming" "development" "multimedia" ];
```

### Adding New Hosts
1. Create a new directory in `hosts/`
2. Add hardware configuration
3. Create `configuration.nix` importing desired profiles
4. Add to `flake.nix` outputs

## 📦 Building Images

Generate ISO and VM images:
```bash
# Live ISOs
nix build .#slax-live-iso
nix build .#brix-live-iso
nix build .#emergency-iso

# VM images
nix build .#slax-vm
nix build .#brix-vm

# nixtv-player
nix build .#nixtv-player-iso
nix build .#nixtv-player-vm
```

### Credential Management for ISOs/VMs

ISOs and VMs use environment variables at build time to configure credentials, avoiding hardcoded passwords in the repository.

**Priority system** (highest to lowest):
1. SOPS secrets (for deployed systems)
2. Environment variables at build time
3. No password (SSH key required)

**Generate a password hash:**
```bash
nix-shell -p mkpasswd --run 'mkpasswd -m sha-512'
```

**Build examples:**
```bash
# Emergency ISO with password authentication
EMERGENCY_PASSWORD_HASH="$(mkpasswd -m sha-512)" nix build .#emergency-iso

# Emergency ISO with SSH key (recommended)
EMERGENCY_SSH_KEY="ssh-ed25519 AAAA..." nix build .#emergency-iso

# nixtv-player ISO with admin password
NIXTV_PASSWORD_HASH="$(mkpasswd -m sha-512)" nix build .#nixtv-player-iso

# Standard host build with user password
USER_PASSWORD_HASH="$(mkpasswd -m sha-512)" sudo nixos-rebuild switch --flake .#slax
```

**Available environment variables:**
| Variable | Used By | Description |
|----------|---------|-------------|
| `USER_PASSWORD_HASH` | All hosts (base.nix) | Password for 'user' account |
| `NIXTV_PASSWORD_HASH` | nixtv-player | Password for 'nixtv' admin account |
| `EMERGENCY_PASSWORD_HASH` | emergency-iso | Root password for recovery ISO |
| `EMERGENCY_SSH_KEY` | emergency-iso | Root SSH public key (disables password login) |

For production deployments, use SOPS secrets instead. See [docs/SOPS-SETUP.md](docs/SOPS-SETUP.md).

## 🔄 Updates

Update the flake and rebuild:
```bash
nix flake update
sudo nixos-rebuild switch --flake .#your-host
home-manager switch --flake .#user@your-host
```

## 🛡️ Security & BIP39/TPM Key Management

### BIP39/TPM Key Bootstrap

This configuration includes an automated bootstrap process for BIP39/TPM key derivation and SOPS setup.

#### Automated Bootstrap Process
```bash
# After your system builds successfully, run the bootstrap script:

# Generate new BIP39 mnemonic and set up everything automatically
./assets/scripts/bootstrap-secrets.sh --generate

# Or use an existing BIP39 mnemonic
./assets/scripts/bootstrap-secrets.sh --mnemonic "word1 word2 ... word24"
```

The bootstrap script will:
1. ✅ Initialize TPM hardware
2. ✅ Generate 24-word BIP39 mnemonic (or use existing)
3. ✅ Derive age encryption keys using HKDF
4. ✅ Update SOPS configuration with new age key
5. ✅ Create encrypted secrets file in `~/.secrets/`
6. ✅ Enable SOPS in system configuration

**⚠️ CRITICAL**: The script will display your 24-word BIP39 mnemonic. Write it down on paper and store it securely - this is your master key for all secrets.

#### Manual Key Management (after bootstrap)
```bash
# List all TPM-stored keys
tpm-keys list

# Get detailed info about a specific key
tpm-keys info 0x81000100

# Extract SSH public key from TPM
tpm-to-pubkey 0x81000100

# Load TPM keys into SSH agent
tpm-ssh-agent

# Remove a key from TPM (destructive!)
tpm-keys remove 0x81000100
```

#### Manual Workflow (if not using bootstrap script)
```bash
# 1. Set up secure secrets directory
mkdir -p ~/.secrets && chmod 700 ~/.secrets

# 2. Generate 24-word mnemonic (save this securely!)
MNEMONIC=$(bip39 generate --words 24 --quiet)
echo "Save this mnemonic securely: $MNEMONIC"

# 3. Initialize TPM
tpm-init

# 4. Create all keys from mnemonic
bip39-unified-keys --mnemonic "$MNEMONIC" --setup-sops --comment "MyDevice"

# 5. Verify keys are stored
tpm-keys list

# 6. Get SSH public key for GitHub/servers
tpm-to-pubkey 0x81000100
```

### Security Model

- **Hardware-Only Storage**: Private keys are sealed in TPM hardware and never stored on disk
- **Deterministic Recovery**: All keys can be recreated from the BIP39 mnemonic on any TPM-enabled device
- **Zero Trust**: Private key material never exists unencrypted outside the TPM
- **Forward Security**: Each operation requires TPM unsealing

### Traditional Security Notes

- **Secrets**: Never commit `secrets.nix` - it's gitignored
- **Keys**: SSH keys and GPG keys are referenced, not embedded
- **Signatures**: Git commits are signed by default
- **Hardening**: System security configurations are applied
- **BIP39 Recovery**: Store your mnemonic phrase securely offline - it's your master key
- **Secure Storage**: Secrets stored in `~/.secrets/` with 700 permissions (owner-only access)

## 🎯 Educational Purpose

This repository serves as an educational example of:
- NixOS flake architecture
- Home Manager integration
- Modular configuration organization
- Security best practices
- Development environment automation

## 📝 License

This configuration is provided as-is for educational purposes. Adapt it to your needs!

## 🤝 Contributing

Feel free to use this configuration as inspiration for your own setup. If you find improvements or have questions, please open an issue!
