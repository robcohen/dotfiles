{ config, pkgs, lib, ... }:

{
  # Beautiful SDDM Display Manager Configuration
  # This is system-level configuration for the login screen

  # Enable SDDM display manager with modern settings
  services.displayManager.sddm = {
    enable = true;
    theme = "catppuccin-mocha";
    package = pkgs.kdePackages.sddm;
    wayland.enable = true;  # Modern Wayland support (2025 best practice)
    
    settings = {
      Theme = {
        Current = "catppuccin-mocha";
        CursorTheme = "catppuccin-mocha-dark-cursors";
        Font = "JetBrains Mono Nerd Font";
        FontSize = "12";
      };
      General = {
        Background = "/etc/nixos/wallpapers/sddm-wallpaper.png";
        DPIScale = 1;
        GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=1,QT_SCALE_FACTOR=1";
      };
    };
  };
  
  # Install the beautiful Catppuccin SDDM theme
  environment.systemPackages = with pkgs; [
    (catppuccin-sddm.override {
      flavor = "mocha";
      font = "JetBrains Mono Nerd Font";
      fontSize = "12";
      background = "${../../assets/backgrounds/nix-wallpaper-dracula.png}";
      loginBackground = true;
    })
    catppuccin-cursors.mochaDark
  ];
  
  # Set up wallpaper for SDDM login screen
  environment.etc."nixos/wallpapers/sddm-wallpaper.png".source = 
    ../../assets/backgrounds/nix-wallpaper-dracula.png;
    
  # Ensure required fonts are available system-wide for SDDM
  fonts.packages = with pkgs; [
    jetbrains-mono
    noto-fonts
    noto-fonts-emoji
    pkgs.nerd-fonts.jetbrains-mono
  ];
}