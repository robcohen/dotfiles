{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: 

{
  imports = [
    ./sway
    ./ags
    ./tmux
    ./fish
    ./alacritty
    ./git
    ./vscode
    ./helix
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
      eww-wayland
      
      # Audio
      pavucontrol
      pulseaudio-ctl
      easyeffects
      spotify
  ];
  
  services.gpg-agent = {
    enable = true;
    enableFishIntegration = true;
    pinentryFlavor = "curses";
  };
 
  home.sessionVariables = {
    EDITOR = "vim";
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

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };
  
  programs.direnv.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];
}
