{ config, pkgs, lib, ... }:

{
  imports = [
    ./fonts.nix
    ./gtk.nix
  ];

  # Desktop-specific programs
  programs = {
    # File managers
    ranger.enable = true;
    
    # Media
    mpv.enable = true;
  };

  # Desktop services
  services = {
    # Clipboard manager would go here if not skipping security for now
  };

  # Desktop-specific packages (non-duplicated)
  home.packages = with pkgs; [
    # Image viewers
    feh
    
    # Archive tools  
    p7zip
    unrar
    
    # File managers (ranger configured via programs.ranger)
    # Terminal already configured via alacritty
  ];
}