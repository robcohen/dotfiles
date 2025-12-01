{ config, pkgs, lib, ... }:

{
  # imv - Image viewer for Wayland
  programs.imv = {
    enable = true;
    settings = {
      options = {
        background = "1e1e2e";  # Catppuccin base
        overlay_font = "Source Code Pro:14";
        overlay_text_color = "cdd6f4";  # Catppuccin text
        overlay_background_color = "313244";  # Catppuccin surface0
        overlay_background_alpha = "dd";
        slideshow_duration = 5;
        suppress_default_binds = false;
      };
      binds = {
        q = "quit";
        "<Shift+X>" = "close";
        "<Left>" = "prev";
        "<Right>" = "next";
        "<Up>" = "zoom 1";
        "<Down>" = "zoom -1";
        j = "prev";
        k = "next";
        h = "pan 50 0";
        l = "pan -50 0";
        gg = "goto 0";
        "<Shift+G>" = "goto -1";
        i = "overlay";
        x = "close";
        f = "fullscreen";
        d = "overlay";
        p = "exec wl-copy < \"$imv_current_file\"";
        r = "reset";
        s = "scaling next";
        a = "zoom actual";
        c = "center";
        "<Shift+H>" = "flip horizontal";
        "<Shift+V>" = "flip vertical";
      };
    };
  };

  # Set imv as default image viewer
  xdg.mimeApps.defaultApplications = {
    "image/png" = [ "imv.desktop" ];
    "image/jpeg" = [ "imv.desktop" ];
    "image/gif" = [ "imv.desktop" ];
    "image/webp" = [ "imv.desktop" ];
    "image/bmp" = [ "imv.desktop" ];
    "image/tiff" = [ "imv.desktop" ];
    "image/svg+xml" = [ "imv.desktop" ];
  };
}
