{ config, pkgs, lib, ... }:

{
  # Multimedia-specific programs
  programs = {
    mpv = {
      enable = true;
      config = {
        hwdec = "auto";
        vo = "gpu";
        profile = "gpu-hq";
        scale = "ewa_lanczossharp";
        cscale = "ewa_lanczossharp";
        video-sync = "display-resample";
        interpolation = true;
        tscale = "oversample";
      };
      bindings = {
        "WHEEL_UP" = "seek 10";
        "WHEEL_DOWN" = "seek -10";
        "j" = "seek -5";
        "l" = "seek 5";
        "J" = "seek -60";
        "L" = "seek 60";
      };
    };
  };

  # Multimedia directories
  xdg.userDirs = {
    music = "${config.home.homeDirectory}/Music";
    videos = "${config.home.homeDirectory}/Videos";
    pictures = "${config.home.homeDirectory}/Pictures";
  };

  # Audio/video file associations (extends mimeapps.nix)
  xdg.mimeApps.defaultApplications = {
    "audio/mpeg" = "mpv.desktop";
    "audio/mp4" = "mpv.desktop";
    "audio/x-flac" = "mpv.desktop";
    "video/mp4" = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "video/webm" = "mpv.desktop";
    "image/jpeg" = "imv.desktop";
    "image/png" = "imv.desktop";
    "image/gif" = "imv.desktop";
  };

  # Multimedia-specific environment
  home.sessionVariables = {
    # Better audio quality
    PULSE_LATENCY_MSEC = "60";
  };
}
