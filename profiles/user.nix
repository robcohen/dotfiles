{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: 

let
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.system;
    config.allowUnfree = true;
  };
  
in {
  imports = [
    ./wofi
    ./sway
    ./tmux
    ./alacritty
    ./git
    ./vscode
    ./helix
    ./zsh
    ./ungoogled-chromium
  ];

  nixpkgs = {
    overlays = [
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  home = {
    username = "user";
    homeDirectory = "/home/user";
  };

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
      wlr-randr
      mako
      alacritty
      shotman
      wofi
      gnupg
      pinentry
      networkmanagerapplet
      waybar
      pciutils
      usbutils
      openssl
      binutils
      ffmpeg
      solaar
      ltunify
      bluez
      light
      xdg-utils
      weston
      v4l-utils
      mpv

      # Automation
      home-assistant-cli
 
      # Productivity
      pdftk
      gnome.seahorse
      age
      sops
      vulnix
      rymdport
      anki
      cmake
      octaveFull

      # VMs / containers
      quickemu
      quickgui
      distrobox
      virt-viewer

      # CLI tools
      niv
      vim
      eza
      bat
      grc
      wget
      unzip
      ranger
      kitty
      dmidecode
      dig
      libfido2
      jq
        
      # Audio
      pavucontrol
      pulseaudio-ctl
      easyeffects
      spotify
      pasystray
      plasma-pa
      carla

      slack 

  ] ++ (with unstable; [ 
      gh
      onlyoffice-bin
      thunderbird
      firefox 
      beancount
      fava
      wineWowPackages.waylandFull
      winetricks
      magic-wormhole-rs
      warp
      telegram-desktop
      element-desktop
      signal-desktop
      bitwarden
      obsidian
      ledger-live-desktop
      okular
      git-repo
  ]); 
 
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave.desktop";
      "x-scheme-handler/http" = "brave.desktop";
      "x-scheme-handler/https" = "brave.desktop";
      "x-scheme-handler/about" = "brave.desktop";
      "x-scheme-handler/unknown" = "brave.desktop";
    };
  };

  programs.brave = {
    enable = true;
    commandLineArgs = [
      "--enable-features=UseOzonePlatform,VaapiVideoDecoder"
      "--ozone-platform=wayland"
      "--enable-accelerated-video-decode"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      ];
  };
 
  ## Services
  
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    defaultCacheTtlSsh = 6*60*60;
  };

  programs.keychain = {
    enable = true;
    keys = [ "id_ed25519" ];
  };
  
  services.pasystray = {
    enable = true;
  };
  
  home.sessionVariables = {
    ELECTRON_DEFAULT_BROWSER = "brave";
    EDITOR = "vim";
    NIXOS_OZONE_WL = "1";
    SSH_AUTH_SOCK = "/run/user/1000/keyring/ssh";
    LIBVA_DRIVER_NAME = "i965";
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };

  ## Sway Settings
  
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.gnome.adwaita-icon-theme;
    size = 24;
    x11 = {
      enable = true;
      defaultCursor = "Adwaita";
      };
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };
  
  programs.waybar = {
  enable = true;
  systemd.enable = true;
  settings = {
    mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      modules-left = [ "sway/workspaces" "sway/mode" ];
      modules-center = [ "sway/window" ];
      modules-right = [
        "tray"
        "network"
        "memory"
        "cpu"
        "battery"
        "temperature"
        "clock#date"
        "clock#time"
        "custom/power"
      ];
      "sway/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
        format = "{name}";
      };
      "custom/power" = {
        format = "  ";
        on-click = "swaynag -t warning -m 'Power Menu Options' -b 'Logout' 'swaymsg exit' -b 'Suspend' 'systemctl suspend' -b 'Shutdown' 'systemctl shutdown' -b 'Reboot' 'systemctl reboot'";
      };
      "clock#date" = {
        format = "{:%a %d %b}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };
    };
  };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
