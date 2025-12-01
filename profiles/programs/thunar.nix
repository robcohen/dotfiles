{ config, pkgs, lib, ... }:

{
  # Thunar - GTK file manager
  home.packages = with pkgs; [
    xfce.thunar
    xfce.thunar-volman      # Volume management
    xfce.thunar-archive-plugin
    xfce.tumbler            # Thumbnail service
    ffmpegthumbnailer       # Video thumbnails
    webp-pixbuf-loader      # WebP support
    poppler                 # PDF thumbnails
  ];

  # Thunar as default file manager
  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "thunar.desktop" ];
  };

  # Enable tumbler service for thumbnails
  services.tumbler.enable = true;
}
