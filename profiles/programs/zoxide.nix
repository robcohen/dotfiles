{ inputs, pkgs, config, ... }:
{
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    options = [
      "--cmd cd"  # Use 'cd' command instead of 'z'
    ];
  };
}