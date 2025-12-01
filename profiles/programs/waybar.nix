{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 48;
        spacing = 4;
        margin-top = 8;
        margin-left = 16;
        margin-right = 16;

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [ "tray" "idle_inhibitor" "bluetooth" "custom/weather" "custom/performance" "pulseaudio" "battery" "custom/power" "clock" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "󰎤";
            "2" = "󰎧";
            "3" = "󰎪";
            "4" = "󰎭";
            "5" = "󰎱";
            "6" = "󰎳";
            "7" = "󰎶";
            "8" = "󰎹";
            "9" = "󰎼";
            "10" = "󰿬";
            urgent = "";
            focused = "";
            default = "󰊠";
            active = "󰮯";
          };
          persistent-workspaces = {
            "*" = 5;
          };
        };


        "hyprland/window" = {
          format = "{}";
          max-length = 50;
          separate-outputs = true;
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰾪";
          };
        };

        tray = {
          spacing = 10;
        };

        clock = {
          format = "󰃰 {:%H:%M}";
          format-alt = "󰃭 {:%Y-%m-%d}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          actions = {
            on-click-right = "mode";
          };
        };


        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰂄 {capacity}%";
          format-alt = "{icon} {time}";
          format-icons = ["󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
        };


        pulseaudio = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon}󰂯 {volume}%";
          format-bluetooth-muted = "󰝟󰂯";
          format-muted = "󰝟";
          format-source = "󰍬 {volume}%";
          format-source-muted = "󰍭";
          format-icons = {
            headphone = "󰋋";
            hands-free = "󰋎";
            headset = "󰋎";
            phone = "󰄜";
            portable = "󰄜";
            car = "󰄋";
            default = ["󰕿" "󰖀" "󰕾"];
          };
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
        };

        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-connected = "󰂱 {num_connections}";
          tooltip-format = "{controller_alias}\t{controller_address}";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          on-click = "${pkgs.alacritty}/bin/alacritty -e ${pkgs.bluetuith}/bin/bluetuith";
        };

        "custom/weather" = {
          format = "{}";
          interval = 1800;
          exec = "${pkgs.writeShellScript "weather-exec" ''
            LOCATION_FILE="$HOME/.config/waybar/weather-location"

            # Default location
            if [ ! -f "$LOCATION_FILE" ]; then
              mkdir -p "$(dirname "$LOCATION_FILE")"
              echo "Austin,TX" > "$LOCATION_FILE"
            fi

            LOCATION=$(cat "$LOCATION_FILE")
            # URL-encode the location (replace spaces with +)
            ENCODED_LOCATION=$(echo "$LOCATION" | sed 's/ /+/g')
            ${pkgs.curl}/bin/curl -s "wttr.in/$ENCODED_LOCATION?format=%c%t&u" 2>/dev/null | tr -d '\n' || echo '󰖙 --°F'
          ''}";
          on-click = "${pkgs.writeShellScript "weather-click" ''
            LOCATION_FILE="$HOME/.config/waybar/weather-location"

            # Get current location for placeholder
            CURRENT=""
            if [ -f "$LOCATION_FILE" ]; then
              CURRENT=$(cat "$LOCATION_FILE")
            fi

            # Prompt for new location using fuzzel
            NEW_LOCATION=$(echo "" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Location (zip or city): " --placeholder "$CURRENT")

            # If user entered something, save it
            if [ -n "$NEW_LOCATION" ]; then
              mkdir -p "$(dirname "$LOCATION_FILE")"
              echo "$NEW_LOCATION" > "$LOCATION_FILE"
              # Signal waybar to refresh the weather module
              pkill -RTMIN+8 waybar
            fi
          ''}";
          signal = 8;
          tooltip = true;
          tooltip-format = "Click to change location";
        };

        "custom/performance" = {
          format = "{}";
          interval = 5;
          exec = "${pkgs.writeShellScript "performance-exec" ''
            STATE_FILE="/tmp/waybar-perf-state"

            # Initialize state file if it doesn't exist
            if [ ! -f "$STATE_FILE" ]; then
              echo "cpu" > "$STATE_FILE"
            fi

            STATE=$(cat "$STATE_FILE")

            case "$STATE" in
              "cpu")
                CPU=$(awk "/cpu / {u=\$2+\$4; t=\$2+\$3+\$4+\$5; print int(100*u/t)}" /proc/stat)
                echo "󰻠 $CPU%"
                ;;
              "memory")
                MEM=$(free | awk "/Mem:/ {printf \"%.0f\", \$3/\$2 * 100.0}")
                echo "󰍛 $MEM%"
                ;;
              "disk")
                DISK=$(df / | awk "NR==2 {print int(\$5)}")
                echo "󰋊 $DISK%"
                ;;
            esac
          ''}";
          on-click = "${pkgs.writeShellScript "performance-click" ''
            STATE_FILE="/tmp/waybar-perf-state"

            # Initialize state file if it doesn't exist
            if [ ! -f "$STATE_FILE" ]; then
              echo "cpu" > "$STATE_FILE"
            fi

            STATE=$(cat "$STATE_FILE")

            case "$STATE" in
              "cpu")
                echo "memory" > "$STATE_FILE"
                ;;
              "memory")
                echo "disk" > "$STATE_FILE"
                ;;
              "disk")
                echo "cpu" > "$STATE_FILE"
                ;;
            esac
          ''}";
          tooltip = true;
          tooltip-format = "Performance Monitor - Click to cycle through CPU/Memory/Disk";
        };

        "custom/power" = {
          format = "⏻";
          tooltip = true;
          tooltip-format = "Power Menu";
          on-click = "wlogout -b 3 -c 3 -r 2 -s -m 0";
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrains Mono Nerd Font", "Font Awesome 6 Free";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: linear-gradient(135deg, rgba(30, 30, 46, 0.95), rgba(24, 24, 37, 0.90));
        color: #cdd6f4;
        border-radius: 16px;
        margin: 8px 16px 0px 16px;
        border: 2px solid rgba(137, 180, 250, 0.3);
        box-shadow:
          0 8px 32px rgba(0, 0, 0, 0.4),
          inset 0 1px 0 rgba(255, 255, 255, 0.1);
      }

      tooltip {
        background: #1e1e2e;
        border-radius: 12px;
        border: 1px solid #89b4fa;
        color: #cdd6f4;
        padding: 10px;
      }

      #workspaces,
      #mode,
      #scratchpad,
      #window,
      #tray,
      #idle_inhibitor,
      #pulseaudio,
      #bluetooth,
      #custom-weather,
      #custom-performance,
      #battery,
      #custom-power,
      #clock {
        background: linear-gradient(135deg, rgba(30, 30, 46, 0.4), rgba(24, 24, 37, 0.3));
        border-radius: 12px;
        margin: 4px 3px;
        padding: 8px 14px;
        border: 1px solid rgba(137, 180, 250, 0.2);
        transition: all 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94);
        box-shadow:
          0 4px 16px rgba(0, 0, 0, 0.15),
          inset 0 1px 0 rgba(255, 255, 255, 0.05);
      }

      #workspaces {
        padding: 4px 8px;
      }

      #workspaces button {
        padding: 4px 8px;
        color: #6c7086;
        border-radius: 8px;
        background: transparent;
        transition: all 0.3s ease;
        margin: 0 2px;
      }

      #workspaces button:hover {
        background: rgba(137, 180, 250, 0.2);
        color: #89b4fa;
      }

      #workspaces button.active {
        background: linear-gradient(135deg, #89b4fa, #74c7ec, #cba6f7);
        color: #11111b;
        font-weight: bold;
        box-shadow:
          0 6px 20px rgba(137, 180, 250, 0.5),
          inset 0 1px 0 rgba(255, 255, 255, 0.3);
        border: 2px solid rgba(255, 255, 255, 0.2);
      }

      #workspaces button.urgent {
        background: linear-gradient(135deg, #f38ba8, #fab387);
        color: #1e1e2e;
        animation: pulse 2s infinite;
      }

      @keyframes pulse {
        from { opacity: 1; }
        to { opacity: 0.8; }
      }

      #window {
        background: rgba(137, 180, 250, 0.1);
        border: 1px solid rgba(137, 180, 250, 0.5);
        color: #89b4fa;
        font-weight: 500;
        font-style: italic;
      }

      #tray > .passive {
        transition: all 0.3s ease;
      }

      #tray > .needs-attention {
        background: rgba(243, 139, 168, 0.2);
        border-color: #f38ba8;
        animation: attention 1s infinite alternate;
      }

      @keyframes attention {
        0% { background: rgba(243, 139, 168, 0.2); }
        100% { background: rgba(243, 139, 168, 0.4); }
      }

      #idle_inhibitor {
        color: #f9e2af;
      }

      #idle_inhibitor.activated {
        background: rgba(249, 226, 175, 0.2);
        border-color: #f9e2af;
        color: #f9e2af;
      }

      #pulseaudio {
        color: #a6e3a1;
      }

      #pulseaudio.muted {
        color: #f38ba8;
        background: rgba(243, 139, 168, 0.1);
      }


      #custom-performance {
        color: #fab387;
      }

      #custom-performance:hover {
        color: #f9e2af;
        background: rgba(250, 179, 135, 0.1);
      }

      @keyframes critical {
        0% { background: rgba(243, 139, 168, 0.2); }
        100% { background: rgba(243, 139, 168, 0.4); }
      }

      #battery {
        color: #a6e3a1;
      }

      #battery.charging {
        color: #f9e2af;
        background: rgba(249, 226, 175, 0.1);
      }

      #battery.warning:not(.charging) {
        color: #fab387;
        background: rgba(250, 179, 135, 0.1);
      }

      #battery.critical:not(.charging) {
        color: #f38ba8;
        background: rgba(243, 139, 168, 0.2);
        animation: critical 1s infinite alternate;
      }

      #bluetooth {
        color: #89b4fa;
      }

      #bluetooth.disabled {
        color: #6c7086;
      }

      #bluetooth.connected {
        color: #a6e3a1;
        background: rgba(166, 227, 161, 0.1);
      }

      #custom-weather {
        color: #f9e2af;
        font-size: 12px;
        padding: 8px 12px;
      }

      #custom-power {
        color: #f38ba8;
        font-size: 16px;
        padding: 8px 12px;
      }

      #custom-power:hover {
        background: rgba(243, 139, 168, 0.2);
        border-color: #f38ba8;
      }

      #clock {
        background: linear-gradient(135deg, rgba(137, 180, 250, 0.3), rgba(116, 199, 236, 0.25), rgba(203, 166, 247, 0.2));
        border: 2px solid rgba(137, 180, 250, 0.4);
        color: #89b4fa;
        font-weight: bold;
        font-size: 14px;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
        box-shadow:
          0 4px 16px rgba(137, 180, 250, 0.4),
          inset 0 1px 0 rgba(255, 255, 255, 0.2);
      }

      /* Hover effects */
      #workspaces,
      #tray,
      #idle_inhibitor,
      #pulseaudio,
      #bluetooth,
      #custom-weather,
      #custom-performance,
      #battery,
      #custom-power,
      #clock {
        transition: all 0.3s ease;
      }

      #tray:hover,
      #idle_inhibitor:hover,
      #pulseaudio:hover,
      #bluetooth:hover,
      #custom-weather:hover,
      #battery:hover,
      #clock:hover {
        background: rgba(137, 180, 250, 0.15);
        border-color: #89b4fa;
        color: #89b4fa;
      }
    '';
  };
}
