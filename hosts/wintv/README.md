# WinTV - Declarative Windows Media Server

Windows host running Podman containers for media services, AI/LLM, and identity management.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  config.nix (Nix - source of truth)                     │
│  ├─ Windows host state (features, packages, firewall)   │
│  └─ Container definitions (media, AI, identity)         │
└────────────────────────┬────────────────────────────────┘
                         │ nix build .#wintv-config
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Generated Files                                        │
│  ├─ docker-compose.yml      (container definitions)     │
│  ├─ configuration.dsc.yaml  (WinGet DSC config)         │
│  ├─ kanidm-server.toml      (identity server)           │
│  └─ deploy.ps1              (deployment script)         │
└────────────────────────┬────────────────────────────────┘
                         │ deploy.ps1 -Apply
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Windows Host (wintv.lorikeet-crested.ts.net)           │
│  └─ Podman containers with GPU passthrough              │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### Build Configuration

```bash
# From dotfiles root
nix build .#wintv-config

# Check generated files
ls result/
```

### Deploy to Windows

```powershell
# Copy result/ folder to Windows host, then run as Administrator:

# Preview changes (dry run)
.\deploy.ps1 -DryRun

# Full deployment
.\deploy.ps1 -Apply

# Only apply Windows configuration (skip containers)
.\deploy.ps1 -ConfigOnly

# Only deploy containers (skip Windows config)
.\deploy.ps1 -ContainersOnly
```

## Configuration

Edit `config.nix` to modify the system. Key sections:

### Windows Host

```nix
windows = {
  # Windows Optional Features
  features = [ "Containers" "Microsoft-Hyper-V-All" ];

  # WinGet packages (use winget search to find IDs)
  packages = [ "RedHat.Podman-Desktop" "Tailscale.Tailscale" ];

  # Firewall rules
  firewall.rules = {
    Jellyfin = { port = 8096; description = "Jellyfin Media Server"; };
  };
};
```

### Containers

```nix
containers = {
  myservice = {
    enable = true;
    image = "docker.io/library/nginx:latest";
    ports = [ "8080:80" ];
    volumes = [ "/mnt/c/Data:/data" ];
    environment = {
      TZ = "America/New_York";
    };
    gpu = false;          # Set true for NVIDIA GPU access
    dependsOn = [];       # Container dependencies
    restart = "unless-stopped";
  };
};
```

### Adding a New Container

1. Add to `config.nix`:
   ```nix
   containers.myapp = {
     enable = true;
     image = "myimage:latest";
     ports = [ "9000:9000" ];
     volumes = [ "/mnt/c/ProgramData/wintv/MyApp:/config" ];
   };
   ```

2. Add firewall rule:
   ```nix
   windows.firewall.rules.MyApp = {
     port = 9000;
     description = "My Application";
   };
   ```

3. Rebuild and deploy:
   ```bash
   nix build .#wintv-config
   # Copy to Windows and run deploy.ps1
   ```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Jellyfin | 8096 | Media streaming (GPU transcoding) |
| Radarr | 7878 | Movie management |
| Sonarr | 8989 | TV show management |
| Prowlarr | 9696 | Indexer manager |
| Lidarr | 8686 | Music management |
| Readarr | 8787 | Book management |
| Bazarr | 6767 | Subtitle management |
| qBittorrent | 8080 | Download client |
| Ollama | 11434 | LLM inference (GPU) |
| Open WebUI | 3000 | Chat interface |
| Kanidm | 8443 | Identity provider (HTTPS) |
| Watchtower | - | Auto-updates (4am daily) |

## File Structure

```
hosts/wintv/
├── config.nix           # Declarative configuration (EDIT THIS)
├── config.json          # Legacy - paths config (deprecated)
├── docker-compose.yml   # Legacy - use generated version instead
├── .env.example         # Environment template
├── setup.ps1            # Legacy bootstrap script
├── bootstrap-remote.ps1 # WinRM setup script
├── configs/
│   ├── Caddyfile            # Reverse proxy (optional)
│   └── kanidm-server.toml   # Kanidm template
└── lib/                 # PowerShell helper modules (legacy)
```

## Initial Setup

### 1. Enable WinRM on Windows

Run `bootstrap-remote.ps1` locally on the Windows machine as Administrator.

### 2. Install Prerequisites

The WinGet Configuration handles this automatically, but manually:
```powershell
winget install RedHat.Podman-Desktop
winget install Tailscale.Tailscale
```

### 3. Configure Tailscale

```powershell
tailscale login
tailscale set --advertise-tags=tag:personal
```

### 4. Generate TLS Certificates

```powershell
$domain = "wintv.lorikeet-crested.ts.net"
tailscale cert --cert-file "C:\ProgramData\wintv\certs\$domain.crt" `
               --key-file "C:\ProgramData\wintv\certs\$domain.key" $domain
```

### 5. Deploy

```bash
nix build .#wintv-config
# Copy to Windows
.\deploy.ps1 -Apply
```

## GPU Access

Containers can access the NVIDIA GPU for:
- Jellyfin hardware transcoding
- Ollama LLM inference
- Tdarr video processing

Set `gpu = true` in container config. Requires:
- NVIDIA drivers on Windows
- NVIDIA Container Toolkit configured for Podman

## Troubleshooting

### Podman not starting after reboot
Podman runs in user mode. Log into Windows first, then:
```powershell
podman machine start
```

### Container can't access GPU
Check NVIDIA Container Toolkit:
```powershell
podman run --rm --device nvidia.com/gpu=all nvidia/cuda:12.0-base nvidia-smi
```

### WinRM connection issues
Verify WinRM is running:
```powershell
Test-WSMan -ComputerName localhost
```

## Migration from Legacy Scripts

The old `setup.ps1` and PowerShell modules in `lib/` are deprecated.
Use the Nix-generated configuration instead:

1. Edit `config.nix` for changes
2. Run `nix build .#wintv-config`
3. Deploy with `deploy.ps1`

The legacy files are kept for reference but should not be used.
