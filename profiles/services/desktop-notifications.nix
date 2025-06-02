{ config, pkgs, lib, hostType, ... }:

{
  # Desktop notification services
  services = lib.mkIf (hostType == "desktop") {
    # Dunst notification daemon
    dunst = {
      enable = true;
      settings = {
        global = {
          monitor = 0;
          follow = "mouse";
          geometry = "350x5-30+20";
          indicate_hidden = "yes";
          shrink = "no";
          transparency = 20;
          notification_height = 0;
          separator_height = 2;
          padding = 8;
          horizontal_padding = 8;
          frame_width = 3;
          frame_color = "#aaaaaa";
          separator_color = "frame";
          sort = "yes";
          idle_threshold = 120;
          font = "Source Code Pro 10";
          line_height = 0;
          markup = "full";
          format = "<b>%s</b>\\n%b";
          alignment = "left";
          show_age_threshold = 60;
          word_wrap = "yes";
          ellipsize = "middle";
          ignore_newline = "no";
          stack_duplicates = true;
          hide_duplicate_count = false;
          show_indicators = "yes";
          icon_position = "left";
          max_icon_size = 32;
          sticky_history = "yes";
          history_length = 20;
          always_run_script = true;
          title = "Dunst";
          class = "Dunst";
        };
        
        urgency_low = {
          background = "#222222";
          foreground = "#888888";
          timeout = 10;
        };
        
        urgency_normal = {
          background = "#285577";
          foreground = "#ffffff";
          timeout = 10;
        };
        
        urgency_critical = {
          background = "#900000";
          foreground = "#ffffff";
          frame_color = "#ff0000";
          timeout = 0;
        };
      };
    };
  };
}