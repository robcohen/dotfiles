{
  inputs,
  pkgs,
  config,
  ...
}:

let
  unstable = import inputs.unstable {
    system = pkgs.system;
    config.allowUnfree = true;
  };

in {

  programs.vscodium = {
    enable = true;
    package = unstable.vscode;
  };
}