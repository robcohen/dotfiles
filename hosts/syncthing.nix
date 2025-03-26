{ config, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    user = "user";
    dataDir = "/home/user/Documents";
    configDir = "/home/user/.config/syncthing";
    overrideDevices = false;
    overrideFolders = false;
    settings = {};
  };
}
