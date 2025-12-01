{ config, pkgs, lib, ... }:

{
  imports = [
    ./fonts.nix
    ./gtk.nix
  ];

  # Desktop-specific programs
  programs = {
    # Media
    mpv.enable = true;
  };

  # Desktop services
  services = {
    # Clipboard manager would go here if not skipping security for now
  };

  # Desktop-specific packages (non-duplicated)
  home.packages = with pkgs; [
    # Archive tools
    p7zip
    unrar
  ];
}
