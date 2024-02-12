{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.zsh = { 
    enable = true;
    enableCompletion = true;
    shellAliases = {
        ls = "${pkgs.eza}/bin/eza";
        ll = "${pkgs.eza}/bin/eza -l";
        la = "${pkgs.eza}/bin/eza -a";
        lt = "${pkgs.eza}/bin/eza --tree";
        lla = "${pkgs.eza}/bin/eza -la";
        cat = "${pkgs.bat}/bin/bat";
        fcode = "env -u WAYLAND_DISPLAY code";
    };  
  };

  { pkgs, ... }:

  {
    enable = true;
    nix-direnv = { enable = true; };
    enableZshIntegration = true;
  }
} 
