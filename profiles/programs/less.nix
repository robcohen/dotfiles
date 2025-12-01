{ inputs, pkgs, config, ... }:
{
  programs.less = {
    enable = true;
    config = ''
      #command
      h left-scroll
      l right-scroll
      0 goto-line
      G goto-end
    '';
  };
}
