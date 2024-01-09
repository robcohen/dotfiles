{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.alacritty = {
    enable = true;
    settings = {
      shell.program = "tmux";
      env.TERM = "alacritty";
      window = {
        decorations = "full";
        title = "Alacritty";
        dynamic_title = true;
        class = {
          instance = "Alacritty";
          general = "Alacritty";
        };
      };
      font = {
        normal = {
          family = "monospace";
          style = "regular";
        };
        bold = {
          family = "monospace";
          style = "regular";
        };
        italic = {
          family = "monospace";
          style = "regular";
        };
        bold_italic = {
          family = "monospace";
          style = "regular";
        };
        size = 14.00;
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
