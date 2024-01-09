{
  inputs,
  pkgs,
  config,
  ...
}:

let
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.system;
    config.allowUnfree = true;
  };

in {

  programs.vscode = {
    enable = true;
    package = unstable.vscode;
  };
}
