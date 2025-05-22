# Create this file: programs/npm.nix
{ config, pkgs, lib, ... }:

{
  # Install nodejs and npm
  home.packages = with pkgs; [
    nodejs_20
  ];

  # Configure npm to install global packages in home directory
  home.file.".npmrc".text = ''
    prefix=$HOME/.npm-packages
    cache=$HOME/.npm-cache
  '';

  # Add npm global bin to PATH
  home.sessionPath = [ "$HOME/.npm-packages/bin" ];

  # Create the npm packages directory
  home.activation.createNpmDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD mkdir -p $HOME/.npm-packages
    $DRY_RUN_CMD mkdir -p $HOME/.npm-cache
  '';
}
