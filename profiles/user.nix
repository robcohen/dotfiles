{
  config,
  pkgs,
  lib,
  inputs,
  unstable,
  hostname,
  username ? "user",
  ...
}:

# Note: `unstable` is passed via extraSpecialArgs from flake.nix
# No need to re-import it here

{
  imports = [
    ./host-specific.nix
    ./packages.nix
    ./session-variables.nix
    ./mimeapps.nix
    ./programs/direnv.nix
    ./programs/gpg.nix
    ./programs/tmux.nix
    ./programs/bash.nix
    ./programs/alacritty.nix
    ./programs/ungoogled-chromium.nix
    ./programs/firefox.nix
    ./programs/git.nix
    ./programs/zsh.nix
    ./programs/npm.nix
    ./programs/home-manager.nix
    ./programs/starship.nix
    ./programs/fzf.nix
    ./programs/eza.nix
    ./programs/bat.nix
    ./programs/ripgrep.nix
    ./programs/dircolors.nix
    ./programs/htop.nix
    ./programs/less.nix
    ./programs/ssh.nix
    ./programs/readline.nix
    ./programs/zoxide.nix
    ./programs/atuin.nix
    ./programs/hyprland.nix
    ./programs/hyprlock.nix
    ./programs/waybar.nix
    ./programs/fuzzel.nix
    ./programs/wlogout.nix
    ./programs/cliphist.nix
    ./programs/hyprshot.nix
    ./programs/thunar.nix
    ./programs/imv.nix
    ./programs/yazi.nix
    ./programs/neovim.nix
    ./programs/claude-code.nix
    ./programs/opencode.nix
    ./programs/gemini-cli.nix
    ./programs/codex-cli.nix
    ./programs/grok-cli.nix
    ./services/gpg-agent.nix
    ./services/swaync.nix
    ./services/syncthing.nix
    ./services/hypridle.nix
    ./services/desktop-notifications.nix
    ./services/system-monitoring.nix
    # Security modules (import after base configurations)
    ./security/default.nix
  ];

  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
      # Curated list of allowed unfree packages (more secure than allowing all)
      allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          # Gaming
          "steam"
          "steam-original"
          "steam-run"
          # Media
          "spotify"
          # Communication
          "slack"
          "discord"
          "zoom"
          # Productivity
          "obsidian"
          "1password"
          "1password-cli"
          # Hardware
          "ledger-live-desktop"
          # Fonts
          "joypixels"
          # NVIDIA (for GPU support)
          "nvidia-x11"
          "nvidia-settings"
          "cuda"
          "cudatoolkit"
        ];
    };
  };

  # Pass hostname to submodules that need it
  _module.args = {
    inherit hostname;
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.11";
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  systemd.user.startServices = "sd-switch";

  # Git configuration - user.name and user.email come from SOPS secrets
  # Edit with: sops ~/.secrets/secrets.yaml (user/name, user/email)

  # Claude Code configuration
  # NOTE: ~/.claude.json is Claude's state file and should not be managed by Home Manager
  # NOTE: Project-specific permissions go in .claude/settings.local.json (gitignored)
  dotfiles.claude-code = {
    enable = true;

    env = {
      # MCP settings
      MCP_TIMEOUT = "10000";
      MCP_TOOL_TIMEOUT = "60000";
      MAX_MCP_OUTPUT_TOKENS = "50000";

      # Extended thinking for complex tasks
      MAX_THINKING_TOKENS = "20000";

      # Output limits
      CLAUDE_CODE_MAX_OUTPUT_TOKENS = "16000";
      BASH_MAX_OUTPUT_LENGTH = "50000";

      # Timeouts
      BASH_DEFAULT_TIMEOUT_MS = "120000";
      BASH_MAX_TIMEOUT_MS = "600000";

      # Privacy - disable non-essential telemetry
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    };

    # Global permissions - tools allowed across all projects
    permissions.allow = [
      # Common shell commands
      "Bash(ls:*)"
      "Bash(du:*)"
      "Bash(find:*)"
      "Bash(grep:*)"
      "Bash(jq:*)"
      "Bash(curl:*)"
      "Bash(ssh:*)"

      # System info
      "Bash(dmesg:*)"
      "Bash(lspci:*)"
      "Bash(boltctl list:*)"

      # Nix tooling
      "Bash(nix-shell:*)"
      "Bash(pre-commit run:*)"

      # Web access
      "WebSearch"
      "WebFetch(domain:github.com)"
      "WebFetch(domain:api.github.com)"
      "WebFetch(domain:raw.githubusercontent.com)"
    ];

    # MCP servers are added via CLI: run `setup-claude-mcp` from nix develop
    # For project-specific DB servers (sqlite, postgres), use .mcp.json
  };

  # SOPS secrets for Home Manager (private infrastructure URLs, etc.)
  # Secrets stored in ~/.secrets/secrets.yaml, decrypted at shell startup
  # Add secrets with: sops ~/.secrets/secrets.yaml
  dotfiles.sops-hm.enable = true;

  # OpenCode configuration (open-source Claude Code alternative)
  # NOTE: API keys via env vars: ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.
  # NOTE: Or use `opencode auth login` for OAuth
  dotfiles.opencode = {
    enable = true;

    # Remote Ollama provider (URL from SOPS secret -> OLLAMA_BASE_URL env var)
    providers.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama";
      options.baseURL = "\${OLLAMA_BASE_URL}";
      models = {
        "qwen2.5-coder:14b" = {
          name = "Qwen 2.5 Coder 14B";
          tools = true;
          options.num_ctx = 32768;
        };
        "deepseek-coder-v2" = {
          name = "DeepSeek Coder V2";
          tools = true;
          options.num_ctx = 16384;
        };
      };
    };
  };

  # Gemini CLI configuration
  # NOTE: Auth via `gemini auth login` (OAuth) or GEMINI_API_KEY env var
  # NOTE: Free tier: 60 req/min, 1000 req/day
  dotfiles.gemini-cli = {
    enable = true;
    # MCP servers can be added here if needed
  };

  # OpenAI Codex CLI configuration
  # NOTE: API key via OPENAI_API_KEY env var
  dotfiles.codex-cli = {
    enable = true;

    # Prevent leaking sensitive env vars to subprocesses
    shellEnvironmentPolicy = {
      inheritEnv = "core";
      exclude = [
        "ANTHROPIC_API_KEY"
        "OPENAI_API_KEY"
        "GEMINI_API_KEY"
        "XAI_API_KEY"
        "GITHUB_TOKEN"
        "AWS_*"
        "AZURE_*"
        "*_SECRET*"
        "*_KEY"
        "*_TOKEN"
      ];
    };

    # Enable useful features
    features = {
      shell_snapshot = true;
    };

    # Remote Ollama as alternative provider (URL from SOPS secret)
    modelProviders.ollama = {
      name = "Ollama";
      base_url = "\${OLLAMA_BASE_URL}";
    };
  };

  # Grok CLI configuration (xAI)
  # NOTE: API key via XAI_API_KEY env var (keys start with "xai-")
  # NOTE: Get key from https://console.x.ai/
  dotfiles.grok-cli = {
    enable = true;
    defaultModel = "grok-3-latest";
    models = [
      "grok-3-latest"
      "grok-3-fast"
      "grok-3-mini-fast"
    ];
  };

  # Add simple debugging info
  home.file.".config/home-manager/host-info.txt".text = ''
    Host: ${hostname}
    User: ${username}
    State Version: 23.11
  '';

  # Add .local/bin and node_modules/bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/node_modules/.bin"
  ];

  # Security tools
  home.packages = with pkgs; [
    age # Modern encryption
    sops # Secrets operations
    lynis # Security auditing tool
    vulnix # Nix vulnerability scanner
    nmap # Network scanner
  ];

  # Simple security scripts
  home.file.".local/bin/security-scan" = {
    text = ''
      #!/usr/bin/env bash
      echo "🔍 Basic Security Scan"
      echo "===================="
      echo ""
      echo "📦 Checking for vulnerable packages..."
      vulnix --system 2>/dev/null | head -5 || echo "No critical vulnerabilities found"
      echo ""
      echo "🌐 Checking open ports..."
      nmap -sT localhost 2>/dev/null | grep open || echo "No open ports detected"
      echo ""
      echo "✅ Basic scan complete. Run 'lynis audit system' for detailed analysis."
    '';
    executable = true;
  };

  # Shell aliases
  home.shellAliases = {
    # Home Manager
    hm-switch = "home-manager switch --flake ~/Documents/dotfiles/#${username}@${hostname}";
    hm-news = "home-manager news --flake ~/Documents/dotfiles/#${username}@${hostname}";
    hm-gens = "home-manager generations";

    # Security
    security-scan = "~/.local/bin/security-scan";
    security-audit = "lynis audit system";
    rootkit-check = "sudo lynis audit system --tests-from-group malware";

    # Network
    lan-mode = "~/Documents/dotfiles/assets/scripts/lan-mode.sh";
  };
}
