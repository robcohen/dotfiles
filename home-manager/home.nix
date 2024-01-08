# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # TODO: Set your username
  home = {
    username = "user";
    homeDirectory = "/home/user";
  };

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
  # programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.11";

  home.packages = with pkgs; [
      # Fonts
      source-code-pro
      font-awesome_4
      font-awesome_5
      font-awesome
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      proggyfonts

      ## Sway & System
      swaylock-effects
      swayidle
      wl-clipboard
      mako
      alacritty
      shotman
      wofi
      gnupg
      pinentry
      networkmanagerapplet
      waybar

      # Productivity
      brave
      onlyoffice-bin
      bitwarden
      bitwarden-cli
      obsidian
      pdftk

      # Crypto
      ledger-live-desktop

      # Communications
      telegram-desktop
      slack
      signal-desktop

      # CLI tools
      niv
      vim
      wev
      eza
      bat
      grc
      wget
      unzip
      tmux
      
      # Audio
      pavucontrol
      pulseaudio-ctl
      easyeffects
      spotify
  ];
  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    prefix = "C-s";
    shell = "${pkgs.fish}/bin/fish";
    terminal = "tmux-256color";
    historyLimit = 100000;
    extraConfig = ''
    bind-key -n C-h select-pane -L
    bind-key -n C-j select-pane -D
    bind-key -n C-k select-pane -U
    bind-key -n C-l select-pane -R

    bind-key - split-window -v -c '#{pane_current_path'
    bind-key '\' split-window -h -c '#{pane_current_path}'

    set -g status-bg '#666666'
    set -g status-fg '#aaaaaa'
    set -g status-left-length 50

    # Fine adjustment (1 or 2 cursor cells per bump)
    bind -n S-Left resize-pane -L 2
    bind -n S-Right resize-pane -R 2
    bind -n S-Down resize-pane -D 1
    bind -n S-Up resize-pane -U 1

    # Coarse adjustment (5 or 10 cursor cells per bump)
    bind -n C-Left resize-pane -L 10
    bind -n C-Right resize-pane -R 10
    bind -n C-Down resize-pane -D 5
    bind -n C-Up resize-pane -U 5

    bind c new-window -c "#{pane_current_path}"
    bind-key b break-pane -d
    
    bind-key C-j choose-tree
    '';
  };
  
  programs.fish = { 
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';
    plugins = [
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
    ];
    shellAliases = {
        ls = "${pkgs.eza}/bin/eza";
        ll = "${pkgs.eza}/bin/eza -l";
        la = "${pkgs.eza}/bin/eza -a";
        lt = "${pkgs.eza}/bin/eza --tree";
        lla = "${pkgs.eza}/bin/eza -la";
        cat = "${pkgs.bat}/bin/bat";
    };  
  };
  
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "alacritty";
      window = {
        decorations = "full";
        title = "Alacritty";
        dynamic_title = true;
        class = {
          instance = "Alacritty";
          general = "Alacritty";
        };
      };
      font = {
        normal = {
          family = "monospace";
          style = "regular";
        };
        bold = {
          family = "monospace";
          style = "regular";
        };
        italic = {
          family = "monospace";
          style = "regular";
        };
        bold_italic = {
          family = "monospace";
          style = "regular";
        };
        size = 14.00;
      };
      # colors = {
      #   primary = {
      #    background = "#1d1f21";
      #    foreground = "#c5c8c6";
      #  };
      # };
    };
  };

  services.gpg-agent = {
    enable = true;
    enableFishIntegration = true;
    pinentryFlavor = "curses";
  };

    
  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhs;
    extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      vscodevim.vim
      yzhang.markdown-all-in-one
    ];
  };
 
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
  };

  home.sessionVariables = {
    EDITOR = "vi";
    NIXOS_OZONE_WL = "1";
  };

  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.gnome.adwaita-icon-theme;
    size = 24;
    x11 = {
      enable = true;
      defaultCursor = "Adwaita";
      };
  };

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    config = rec {
      modifier = "Mod4";
      terminal = "alacritty"; 
      menu = "wofi --show run";
      startup = [
        # Launch Firefox on start
        {command = "nm-applet --indicator";}
      ];
      bars = [{
        command = "waybar";
      }];
      output = {
          eDP-1 = {
            mode = "3456x2160@60Hz";
            # Set HIDP scale (pixel integer scaling)
            scale = "2";
	      };
	    };
    };
    extraConfig = ''
      gaps inner 8
      bindsym Print               exec 'shotman -c output'
      bindsym Print+Shift         exec 'shotman -c region'
      bindsym Print+Shift+Control exec 'shotman -c window'
      
      # Brightness
      bindsym Mod4+Control+Down exec 'light -U 10'
      bindsym Mod4+Control+Up exec 'light -A 10'

      # Volume
      bindsym Mod4+Control+Right exec 'pactl set-sink-volume @DEFAULT_SINK@ +1%'
      bindsym Mod4+Control+Left exec 'pactl set-sink-volume @DEFAULT_SINK@ -1%'
      bindsym Mod4+Control+m exec 'pactl set-sink-mute @DEFAULT_SINK@ toggle'

      bindsym Mod4+z exec 'swaylock \
	      --screenshots \
	      --clock \
	      --indicator \
	      --indicator-radius 100 \
	      --indicator-thickness 7 \
	      --effect-blur 15x5 \
	      --effect-vignette 0.2:0.5 \
	      --ring-color bb00cc \
	      --key-hl-color 880033 \
	      --line-color 00000000 \
	      --inside-color 00000088 \
	      --separator-color 00000000 \
	      --grace 2 \
	      --fade-in 0.2'
    '';
  };

  programs.direnv.enable = true;

  programs.waybar.settings = { 
    style = ''
      {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;
          output = [
            "eDP-1"
          ];
          modules-left = [ "sway/workspaces" "sway/mode" "wlr/taskbar" ];
          modules-center = [ "sway/window" "custom/hello-from-waybar" ];

          "sway/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };         
        };
      }
    '';
  };

  programs.git = {
      # Install git
      enable = true;
      
    # Additional options for the git program
    package = pkgs.gitAndTools.gitFull; # Install git wiith all the optional extras
    userName = "robcohen";
    userEmail = "robcohen@users.noreply.github.com";
    extraConfig = {
      # Use vim as our default git editor
      core.editor = "vim";
      # Cache git credentials for 15 minutes
      credential.helper = "cache";
    };
  };
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];
}
