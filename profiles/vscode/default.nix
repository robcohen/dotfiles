{
  inputs,
  pkgs,
  config,
  ...
}:{

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };
}