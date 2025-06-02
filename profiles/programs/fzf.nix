{ inputs, pkgs, config, ... }:
{
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    defaultCommand = "${pkgs.fd}/bin/fd --type f";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
    fileWidgetCommand = "${pkgs.fd}/bin/fd --type f";
    historyWidgetOptions = [
      "--sort"
      "--exact"
    ];
  };
}