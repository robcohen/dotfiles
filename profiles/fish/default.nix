{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.fish = { 
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';
    plugins = [
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
    ];
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
} 