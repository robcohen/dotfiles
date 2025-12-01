{ config, pkgs, lib, ... }:

{
  # Cliphist - Clipboard manager for Wayland
  home.packages = with pkgs; [
    cliphist
    wl-clipboard
  ];

  # Clipboard history service
  systemd.user.services.cliphist = {
    Unit = {
      Description = "Clipboard history service";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Image clipboard history
  systemd.user.services.cliphist-images = {
    Unit = {
      Description = "Clipboard history service for images";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
