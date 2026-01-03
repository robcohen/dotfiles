{ config, pkgs, lib, unstable, hostConfig, hostFeatures, hostType, ... }:

let
  hasFeature = feature: builtins.elem feature hostFeatures;
  isDesktop = hostType == "desktop";
  isServer = hostType == "server";

  # Core packages for all systems
  fonts = with pkgs; [
    source-code-pro font-awesome_4 font-awesome_5 font-awesome
    noto-fonts noto-fonts-cjk-sans noto-fonts-color-emoji
    liberation_ttf fira-code fira-code-symbols proggyfonts
  ];

  # Base system utilities (all hosts)
  baseSystemUtils = with pkgs; [
    gnupg pinentry-gnome3
    pciutils usbutils openssl binutils
    age sops vulnix niv vim
    dmidecode dig libfido2 jq opensc pcsc-tools ccid
  ];

  # Desktop-specific packages
  desktopUtils = with pkgs; [
    networkmanagerapplet light xdg-utils
    ffmpeg v4l-utils home-assistant-cli pdftk seahorse
    grc wget unzip  # Removed duplicated tools: eza, bat, htop, btop, ripgrep, ranger, wl-clipboard (in base.nix)
    hyprlock hypridle  # Screen locking and idle management
    hyprnome  # GNOME-like workspace navigation
  ];

  # Development packages (conditional)
  devPackages = with pkgs; lib.optionals (hasFeature "development") [
    cmake octaveFull quickemu quickgui distrobox virt-viewer
    llama-cpp fd yq tree pre-commit
  ];

  # Gaming packages (conditional)
  gamingPackages = with unstable; lib.optionals (hasFeature "gaming") [
    steam fallout2-ce looking-glass-client
  ];

  # Multimedia packages (conditional)
  multimediaPackages = with pkgs; lib.optionals (hasFeature "multimedia") [
    mpv pavucontrol pulseaudio-ctl easyeffects spotify
    pasystray kdePackages.plasma-pa carla
  ] ++ lib.optionals (hasFeature "multimedia") (with unstable; [
    obs-studio-plugins.looking-glass-obs obs-studio
  ]);

  # Hardware-specific packages (conditional)
  hardwarePackages = with pkgs; lib.optionals isDesktop [
    solaar ltunify bluetuith bluez
  ];

  # Communication packages
  communicationPackages = with pkgs; [
    slack
  ] ++ (with unstable; [
    telegram-desktop signal-desktop
  ]);

  # Productivity packages
  productivityPackages = with pkgs; [
    rymdport anki nil rclone google-chrome
  ] ++ (with unstable; [
    gh onlyoffice-desktopeditors thunderbird firefox tor-browser
    warp bitwarden-desktop obsidian ledger-live-desktop kdePackages.okular
    git-repo gpa zed-editor aichat logseq
  ]);

  # Wine packages (conditional)
  winePackages = with unstable; lib.optionals (hasFeature "gaming" || hasFeature "development") [
    wineWowPackages.waylandFull winetricks magic-wormhole-rs
  ];

  # Development tools (conditional)
  devToolPackages = with unstable; lib.optionals (hasFeature "development") [
    radicle-node devenv qFlipper cachix opencode
  ];

in {
  home.packages = fonts ++ baseSystemUtils ++
    lib.optionals isDesktop desktopUtils ++
    devPackages ++ gamingPackages ++ multimediaPackages ++
    hardwarePackages ++ communicationPackages ++
    productivityPackages ++ winePackages ++ devToolPackages;
}
