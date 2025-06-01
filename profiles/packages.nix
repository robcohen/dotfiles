{ pkgs, unstable, ... }:

let
  fonts = with pkgs; [
    source-code-pro font-awesome_4 font-awesome_5 font-awesome
    noto-fonts noto-fonts-cjk-sans noto-fonts-emoji
    liberation_ttf fira-code fira-code-symbols proggyfonts
  ];

  systemUtils = with pkgs; [
    gnupg pinentry-gnome3 networkmanagerapplet
    pciutils usbutils openssl binutils ffmpeg solaar ltunify
    bluez light xdg-utils weston v4l-utils mpv bluetuith
    home-assistant-cli pdftk seahorse age sops vulnix rymdport
    anki cmake octaveFull quickemu quickgui distrobox
    virt-viewer niv vim eza bat grc wget unzip ranger
    kitty dmidecode dig libfido2 jq opensc pcsctools ccid
    pavucontrol pulseaudio-ctl easyeffects spotify
    pasystray kdePackages.plasma-pa carla slack
    # User CLI and development tools
    llama-cpp htop btop ripgrep fd yq tree
  ];

  unstableApps = with unstable; [
    gh onlyoffice-bin thunderbird firefox tor-browser
    wineWowPackages.waylandFull winetricks magic-wormhole-rs
    warp telegram-desktop signal-desktop bitwarden
    obsidian ledger-live-desktop kdePackages.okular git-repo
    gpa steam zed-editor aichat fallout2-ce looking-glass-client
    obs-studio-plugins.looking-glass-obs obs-studio
    radicle-node devenv qflipper cachix
  ];
in {
  home.packages = fonts ++ systemUtils ++ unstableApps;
}
