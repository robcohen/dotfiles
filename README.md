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
   ```

3. **Apply configuration:**
   ```bash
   # For desktop hosts (slax/brix)
   sudo nixos-rebuild switch --flake .#slax
   
   # Apply home-manager configuration
   home-manager switch --flake .#user@slax
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

# QCOW2 images
nix build .#slax-qcow2
nix build .#brix-qcow2
```

## 🔄 Updates

Update the flake and rebuild:
```bash
nix flake update
sudo nixos-rebuild switch --flake .#your-host
home-manager switch --flake .#user@your-host
```

## 🛡️ Security Notes

- **Secrets**: Never commit `secrets.nix` - it's gitignored
- **Keys**: SSH keys and GPG keys are referenced, not embedded
- **Signatures**: Git commits are signed by default
- **Hardening**: System security configurations are applied

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
