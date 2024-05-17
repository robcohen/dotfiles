{ config, pkgs, ... }:
{
  programs.osh = {
    enable = true;
    interactiveShellInit = ''
      # Enable autocompletion
      source ${pkgs.oil}/share/oil/completion.osh
    '';
  };
}