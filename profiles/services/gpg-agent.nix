{ pkgs, ... }:

{
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    defaultCacheTtlSsh = 6 * 60 * 60;
    enableScDaemon = true;
    pinentryPackage = pkgs.pinentry-gnome3;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
    '';
  };
}
