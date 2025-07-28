{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 40;
        spacing = 4;
        margin-top = 8;
        margin-left = 16;
        margin-right = 16;

        modules-left = [ "hyprland/workspaces" "hyprland/mode" "hyprland/scratchpad" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [ "tray" "idle_inhibitor" "pulseaudio" "network" "cpu" "memory" "temperature" "battery" "clock" ];

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

        "hyprland/mode" = {
          format = "<span style=\"italic\">{}</span>";
        };

        "hyprland/scratchpad" = {
          format = "{icon} {count}";
          show-empty = false;
          format-icons = ["" ""];
          tooltip = true;
          tooltip-format = "{app}: {title}";
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

        cpu = {
          format = "󰻠 {usage}%";
          tooltip = false;
        };

        memory = {
          format = "󰍛 {}%";
        };

        temperature = {
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = ["" "" ""];
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

        network = {
          format-wifi = "󰤨 {essid} ({signalStrength}%)";
          format-ethernet = "󰈀 {ipaddr}/{cidr}";
          tooltip-format = "󰈀 {ifname} via {gwaddr}";
          format-linked = "󰈀 {ifname} (No IP)";
          format-disconnected = "󰤭 Disconnected";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
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
        background: rgba(17, 17, 27, 0.8);
        color: #cdd6f4;
        border-radius: 16px;
        margin: 8px 16px 0px 16px;
        border: 2px solid rgba(137, 180, 250, 0.3);
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
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
      #network,
      #cpu,
      #memory,
      #temperature,
      #battery,
      #clock {
        background: linear-gradient(135deg, rgba(30, 30, 46, 0.95), rgba(24, 24, 37, 0.9));
        border-radius: 14px;
        margin: 6px 4px;
        padding: 8px 16px;
        border: 2px solid rgba(137, 180, 250, 0.2);
        transition: all 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94);
        box-shadow:
          0 4px 16px rgba(0, 0, 0, 0.2),
          inset 0 1px 0 rgba(255, 255, 255, 0.1);
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

      #network {
        color: #74c7ec;
      }

      #network.disconnected {
        color: #f38ba8;
        background: rgba(243, 139, 168, 0.1);
      }

      #cpu {
        color: #fab387;
      }

      #memory {
        color: #cba6f7;
      }

      #temperature {
        color: #f9e2af;
      }

      #temperature.critical {
        color: #f38ba8;
        background: rgba(243, 139, 168, 0.2);
        animation: critical 1s infinite alternate;
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
      #network,
      #cpu,
      #memory,
      #temperature,
      #battery,
      #clock {
        transition: all 0.3s ease;
      }

      #pulseaudio:hover,
      #network:hover,
      #cpu:hover,
      #memory:hover,
      #temperature:hover,
      #battery:hover,
      #clock:hover {
        box-shadow: 0 4px 12px rgba(137, 180, 250, 0.2);
        border-color: rgba(137, 180, 250, 0.8);
      }
    '';
  };
}
