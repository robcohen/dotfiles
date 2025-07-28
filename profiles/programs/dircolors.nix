{ inputs, pkgs, config, ... }:
{
  programs.dircolors = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
}
