{ inputs, pkgs, config, ... }:
{
  programs.ripgrep = {
    enable = true;
    arguments = [
      "--max-columns-preview"
      "--colors=line:style:bold"
      "--smart-case"
    ];
  };
}
