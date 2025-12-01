{ config, pkgs, lib, ... }:

{
  # Hyprshot - Screenshot utility for Hyprland
  home.packages = with pkgs; [
    hyprshot
    grim
    slurp
    swappy  # Annotation tool
  ];
}
