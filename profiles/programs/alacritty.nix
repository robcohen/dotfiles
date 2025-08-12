{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.alacritty = {
    enable = true;
    settings = {
      terminal.shell.program = "tmux";
      env.TERM = "alacritty";
      window = {
        decorations = "full";
        title = "Alacritty";
        dynamic_title = true;
        opacity = 0.9;
        class = {
          instance = "Alacritty";
          general = "Alacritty";
        };
      };
      font = {
        normal = {
          family = "Source Code Pro";
          style = "Regular";
        };
        bold = {
          family = "Source Code Pro";
          style = "Bold";
        };
        italic = {
          family = "Source Code Pro";
          style = "Italic";
        };
        bold_italic = {
          family = "Source Code Pro";
          style = "Bold Italic";
        };
        size = 14.0;
      };
      # colors = {
      #   primary = {
      #    background = "#1d1f21";
      #    foreground = "#c5c8c6";
      #  };
      # };
    };
  };
}
