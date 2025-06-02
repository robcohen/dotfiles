{ config, pkgs, lib, hostConfig, hostFeatures, hostType, ... }:

let
  hasFeature = feature: builtins.elem feature hostFeatures;
  isDesktop = hostType == "desktop";
  isServer = hostType == "server";
in {
  # Conditional imports based on host type and features
  imports = [];

  # Host-specific session variables
  home.sessionVariables = lib.mkMerge [
    (lib.mkIf isServer {
      # Server-specific variables
      TERM = "xterm-256color";
      EDITOR = "vim";  # Prefer vim on servers
    })
    (lib.mkIf (hasFeature "gaming") {
      # Gaming optimizations
      __GL_SHADER_DISK_CACHE = "1";
      __GL_SHADER_DISK_CACHE_PATH = "${config.xdg.cacheHome}/nv";
      # Disable composition for gaming
      __GL_SYNC_TO_VBLANK = "0";
    })
    (lib.mkIf (hasFeature "development") {
      # Development environment variables
      NIXPKGS_ALLOW_UNFREE = "1";
      USE_DOCKER = "1";
    })
  ];

  # Conditional program enabling based on features
  programs = {
    # Desktop applications
    alacritty.enable = lib.mkDefault isDesktop;
    
    # Server-specific configurations
    git.extraConfig = lib.mkMerge [
      (lib.mkIf isServer {
        # Server-specific git config
        core.autocrlf = false;
        init.defaultBranch = "main";
        pull.rebase = true;
      })
      (lib.mkIf (hasFeature "development") {
        # Development-specific git config
        rerere.enabled = true;
        branch.autosetupmerge = "always";
        branch.autosetuprebase = "always";
      })
    ];

    # Gaming-specific programs
    mangohud.enable = lib.mkDefault (hasFeature "gaming");
    
    # Development tools
    direnv.enable = lib.mkDefault (hasFeature "development" || isDesktop);
  };

  # Feature-specific services
  services = {
    # Gaming: disable power management for performance
    poweralertd.enable = lib.mkDefault (!hasFeature "gaming");
  };
}