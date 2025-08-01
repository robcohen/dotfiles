{ config, pkgs, lib, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    settings = {
      # Monitor configuration
      monitor = [
        ",preferred,auto,auto"
      ];

      # Input configuration
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
        };
        sensitivity = 0;
      };

      # General settings
      general = {
        gaps_in = 5;
        gaps_out = 20;
        border_size = 2;
        "col.active_border" = "rgba(74c7ecff) rgba(89b4faff) rgba(cba6f7ff) 45deg";
        "col.inactive_border" = "rgba(313244aa)";
        layout = "dwindle";
      };

      # Decoration
      decoration = {
        rounding = 16;

        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          xray = true;
          contrast = 1.17;
          brightness = 0.8;
        };

        shadow = {
          enabled = true;
          range = 20;
          render_power = 3;
          color = "rgba(0d1117ee)";
          offset = "0 8";
        };

        # Glass-like effect
        active_opacity = 0.95;
        inactive_opacity = 0.85;
        fullscreen_opacity = 1.0;
      };

      # Animations
      animations = {
        enabled = true;

        bezier = [
          "wind, 0.05, 0.9, 0.1, 1.05"
          "winIn, 0.1, 1.1, 0.1, 1.1"
          "winOut, 0.3, -0.3, 0, 1"
          "liner, 1, 1, 1, 1"
          "linear, 0.0, 0.0, 1.0, 1.0"
        ];

        animation = [
          "windows, 1, 6, wind, slide"
          "windowsIn, 1, 6, winIn, slide"
          "windowsOut, 1, 5, winOut, slide"
          "windowsMove, 1, 5, wind, slide"
          "border, 1, 10, default"
          "borderangle, 1, 100, linear, loop"
          "fade, 1, 8, default"
          "workspaces, 1, 5, wind"
          "specialWorkspace, 1, 8, wind, slidevert"
        ];
      };

      # Layout settings
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      # Gestures
      gestures = {
        workspace_swipe = false;
      };

      # Misc settings
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        enable_swallow = true;
        swallow_regex = "^(Alacritty)$";
        focus_on_activate = true;
        vfr = true;
      };

      # Device configuration
      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      # Key bindings
      "$mainMod" = "SUPER";

      bind = [
        # Application launchers
        "$mainMod, Q, exec, alacritty"
        "$mainMod, C, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, ranger"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, rofi -show drun"
        "$mainMod, P, pseudo, # dwindle"
        "$mainMod, J, togglesplit, # dwindle"

        # Move focus with mainMod + arrow keys
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"

        # Move focus with mainMod + vim keys
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Example special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"

        # Screenshot bindings
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "$mainMod, Print, exec, grim - | wl-copy"

        # Media keys
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ +5%"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ -5%"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"

        # Brightness keys
        ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # Window rules
      windowrulev2 = [
        "float, class:^(pavucontrol)$"
        "float, class:^(blueman-manager)$"
        "float, class:^(nm-connection-editor)$"
        "float, class:^(file_progress)$"
        "float, class:^(confirm)$"
        "float, class:^(dialog)$"
        "float, class:^(download)$"
        "float, class:^(notification)$"
        "float, class:^(error)$"
        "float, class:^(splash)$"
        "float, class:^(confirmreset)$"
        "float, title:^(Open File)(.*)$"
        "float, title:^(Select a File)(.*)$"
        "float, title:^(Choose wallpaper)(.*)$"
        "float, title:^(Open Folder)(.*)$"
        "float, title:^(Save As)(.*)$"
        "float, title:^(Library)(.*)$"
      ];

      # Startup applications
      exec-once = [
        "swww-daemon"
        "sleep 1 && swww img ~/Documents/dotfiles/assets/backgrounds/nix-wallpaper-dracula.png"
        "waybar"
        "dunst"
        # Start authentication agent
        "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
      ];
    };
  };
}
