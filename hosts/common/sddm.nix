{ config, pkgs, lib, ... }:

let
  cfg = config.services.displayManager.sddm;
  defaultWallpaper = ../../assets/backgrounds/nix-wallpaper-dracula.png;
in
{
  options.services.displayManager.sddm.wallpaper = lib.mkOption {
    type = lib.types.path;
    default = defaultWallpaper;
    description = "Path to SDDM login screen wallpaper";
  };

  config = {
  # Beautiful SDDM Display Manager Configuration
  # This is system-level configuration for the login screen

  # Enable SDDM display manager with modern settings
  services.displayManager.sddm = {
    enable = true;
    theme = "catppuccin-mocha-maroon";
    package = pkgs.kdePackages.sddm;
    wayland.enable = true;  # Modern Wayland support (2025 best practice)

    settings = {
      Theme = {
        Current = "catppuccin-mocha-maroon";
        CursorTheme = "catppuccin-mocha-dark-cursors";
        Font = "JetBrains Mono Nerd Font";
        FontSize = "12";
      };
      General = {
        Background = "/etc/nixos/wallpapers/sddm-wallpaper.png";
        DPIScale = 1;
        GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=1,QT_SCALE_FACTOR=1";
        # Ensure display-manager starts after graphics are ready
        DisplayServer = "wayland";
      };
      Wayland = {
        # Wayland-specific settings
        CompositorCommand = "${pkgs.weston}/bin/weston --backend=drm";
        # SessionDir is automatically detected by SDDM
      };
    };
  };

  # Ensure display manager waits for Plymouth to finish
  systemd.services.display-manager = {
    after = [ "plymouth-quit.service" "plymouth-quit-wait.service" ];
    wants = [ "plymouth-quit.service" "plymouth-quit-wait.service" ];
    # Add a small delay to ensure GPU is ready
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
    };
  };

  # Install the beautiful Catppuccin SDDM theme
  environment.systemPackages = [
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "maroon";
      font = "JetBrains Mono Nerd Font";
      fontSize = "12";
      background = "${cfg.wallpaper}";
      loginBackground = true;
    })
    pkgs.catppuccin-cursors.mochaDark
  ];

  # Set up wallpaper for SDDM login screen
  environment.etc."nixos/wallpapers/sddm-wallpaper.png".source = cfg.wallpaper;

  # Ensure required fonts are available system-wide for SDDM
  fonts.packages = [
    pkgs.jetbrains-mono
    pkgs.noto-fonts
    pkgs.noto-fonts-color-emoji
    pkgs.nerd-fonts.jetbrains-mono
  ];
  };  # Close config block
}
