{
  inputs,
  pkgs,
  config,
  ...
}: {

programs.ags = {
    enable = true;

    configDir = ../ags;

    # additional packages to add to gjs's runtime
    extraPackages = [ pkgs.libsoup_3 ];
  };
}