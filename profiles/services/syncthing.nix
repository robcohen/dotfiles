{ pkgs, ... }:

{

  services.syncthing = {
  enable = true;
  tray = {
        enable = false;  # Disabled since using eww for system tray
        command = "syncthingtray";
    };
  };
}
