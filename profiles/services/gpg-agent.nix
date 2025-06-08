{ pkgs, ... }:

{
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    defaultCacheTtlSsh = 6 * 60 * 60;
    enableScDaemon = true;
    pinentry.package = pkgs.pinentry-gtk2;
  };
}
