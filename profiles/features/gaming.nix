{ config, pkgs, lib, ... }:

{
  # Gaming-specific programs
  programs = {
    mangohud = {
      enable = true;
      settings = {
        cpu_temp = true;
        gpu_temp = true;
        fps = true;
        frametime = true;
        position = "top-left";
      };
    };
  };

  # Gaming-specific packages already handled conditionally in packages.nix

  # Gaming-optimized XDG directories
  xdg.userDirs = {
    # Create dedicated gaming directories
    extraConfig = {
      XDG_GAMES_DIR = "${config.home.homeDirectory}/Games";
    };
  };

  # Gaming-specific session variables (already in host-specific.nix)

  home.file.".local/share/applications/gaming-mode.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Gaming Mode
    Comment=Enable gaming optimizations
    Exec=${pkgs.gamemode}/bin/gamemoderun
    Icon=applications-games
    Categories=Game;
  '';
}
