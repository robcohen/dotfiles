{ inputs, pkgs, config, ... }:
{
  programs.readline = {
    enable = true;
    bindings = {
      "\\e[A" = "history-search-backward";
      "\\e[B" = "history-search-forward";
      "\\C-w" = "unix-filename-rubout";
    };
    variables = {
      completion-ignore-case = true;
      completion-map-case = true;
      show-all-if-ambiguous = true;
      show-all-if-unmodified = true;
      visible-stats = true;
      mark-symlinked-directories = true;
      colored-stats = true;
      colored-completion-prefix = true;
    };
  };
}