{
  inputs,
  pkgs,
  config,
  ...
}: {

wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    config = rec {
      modifier = "Mod4";
      terminal = "alacritty"; 
      menu = "wofi --show run";
      startup = [
        # Launch Firefox on start
        {command = "nm-applet --indicator";}
      ];
      bars = [{
        #command = "waybar";
      }];
      output = {
          DP-1 = {
            # Set HIDP scale (pixel integer scaling)
            scale = "1.3";
	      };
	    };
    };
    extraConfig = ''
      for_window [window_role = "pop-up"] floating enable
      for_window [window_role = "bubble"] floating enable
      for_window [window_role = "dialog"] floating enable
      for_window [window_type = "dialog"] floating enable
      for_window [window_role = "task_dialog"] floating enable
      for_window [window_type = "menu"] floating enable
      for_window [app_id = "floating"] floating enable
      for_window [app_id = "floating_update"] floating enable, resize set width 1000px height 600px
      for_window [class = "(?i)pinentry"] floating enable
      for_window [title = "Administrator privileges required"] floating enable
      gaps inner 8
      bindsym Print               exec 'shotman -c output'
      bindsym Print+Shift         exec 'shotman -c region'
      bindsym Print+Shift+Control exec 'shotman -c window'
      
      # Brightness
      bindsym Mod4+Control+Down exec 'light -U 10'
      bindsym Mod4+Control+Up exec 'light -A 10'

      # Volume
      bindsym Mod4+Control+Right exec 'pactl set-sink-volume @DEFAULT_SINK@ +1%'
      bindsym Mod4+Control+Left exec 'pactl set-sink-volume @DEFAULT_SINK@ -1%'
      bindsym Mod4+Control+m exec 'pactl set-sink-mute @DEFAULT_SINK@ toggle'

      bindsym Mod4+z exec 'swaylock \
	      --screenshots \
	      --clock \
	      --indicator \
	      --indicator-radius 100 \
	      --indicator-thickness 7 \
	      --effect-blur 15x5 \
	      --effect-vignette 0.2:0.5 \
	      --ring-color bb00cc \
	      --key-hl-color 880033 \
	      --line-color 00000000 \
	      --inside-color 00000088 \
	      --separator-color 00000000 \
	      --grace 2 \
	      --fade-in 0.2'
    '';
  };
  
}
