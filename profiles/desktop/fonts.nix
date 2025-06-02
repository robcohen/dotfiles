{ config, pkgs, lib, ... }:

{
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Noto Serif" "Liberation Serif" ];
      sansSerif = [ "Noto Sans" "Liberation Sans" ];
      monospace = [ "Source Code Pro" "Liberation Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
    
    hinting = {
      enable = true;
      autohint = false;
      style = "slight";
    };
    
    subpixel = {
      lcdfilter = "default";
      rgba = "rgb";
    };
    
    antialias = true;
  };
}