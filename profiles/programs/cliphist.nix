{ config, pkgs, lib, ... }:

{
  # Cliphist - Clipboard manager for Wayland
  # Note: wl-clipboard-rs is provided by hosts/common/base.nix
  home.packages = with pkgs; [
    cliphist
  ];

  # Clipboard history service
  systemd.user.services.cliphist = {
    Unit = {
      Description = "Clipboard history service";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard-rs}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
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
      ExecStart = "${pkgs.wl-clipboard-rs}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
