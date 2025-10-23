{ config, pkgs, lib, ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        grace = 0;  # No grace period - lock immediately
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot";  # Takes a screenshot and blurs it
          blur_passes = 3;
          blur_size = 8;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          size = "300, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(30, 30, 46)";
          outer_color = "rgb(137, 180, 250)";
          outline_thickness = 3;
          placeholder_text = "<span foreground=\"##cad3f5\">Password...</span>";
          shadow_passes = 2;
        }
      ];

      label = [
        # Time
        {
          text = "cmd[update:1000] echo \"$(date +\"%H:%M\")\"";
          color = "rgb(202, 211, 245)";
          font_size = 90;
          font_family = "Fira Code";
          position = "0, 160";
          halign = "center";
          valign = "center";
        }
        # Date
        {
          text = "cmd[update:43200000] echo \"$(date +\"%A, %d %B %Y\")\"";
          color = "rgb(202, 211, 245)";
          font_size = 25;
          font_family = "Fira Code";
          position = "0, 80";
          halign = "center";
          valign = "center";
        }
        # User
        {
          text = "   $USER";
          color = "rgb(202, 211, 245)";
          font_size = 18;
          font_family = "Fira Code";
          position = "0, -150";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
