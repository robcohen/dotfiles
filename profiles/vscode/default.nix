{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhs;
    extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
    ];
  };
}