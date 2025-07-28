{ config, pkgs, lib, ... }:

{
  programs.eww = {
    enable = true;
    configDir = config.xdg.configHome + "/eww";
  };

  xdg.configFile."eww/eww.yuck".text = ''
    ;; Variables
    (defvar eww "${pkgs.eww}/bin/eww")

    ;; Windows
    (defwindow bar
      :monitor 0
      :windowtype "dock"
      :geometry (geometry
        :x "0%"
        :y "0%"
        :width "100%"
        :height "30px"
        :anchor "top center")
      :stacking "fg"
      :exclusive true
      :focusable false
      (bar))

    ;; Widgets
    (defwidget bar []
      (centerbox :orientation "h"
        (workspaces)
        (music)
        (sidestuff)))

    (defwidget sidestuff []
      (box :class "sidestuff" :orientation "h" :space-evenly false :halign "end"
        (metric :label "🔊"
                :value volume
                :onchange "wpctl set-volume @DEFAULT_AUDIO_SINK@ {}%")
        (metric :label "💾"
                :value {EWW_RAM.used_mem_perc}
                :onchange "")
        (time)))

    (defwidget workspaces []
      (box :class "workspaces"
           :orientation "h"
           :space-evenly true
           :halign "start"
           :spacing 10
        (label :text "${workspaces}${current_workspace}")))

    (defwidget music []
      (box :class "music"
           :orientation "h"
           :space-evenly false
           :halign "center"
        {music != "" ? "🎵${music}" : ""}))

    (defwidget metric [label value onchange]
      (box :orientation "h"
           :class "metric"
           :space-evenly false
        (box :class "label" label)
        (scale :min 0
               :max 101
               :active {onchange != ""}
               :value value
               :onchange onchange)))

    (defwidget time []
      (box :class "time" :orientation "h" :space-evenly false :halign "end"
        (label :text time)))

    ;; Variables
    (defpoll time :interval "10s"
      "date '+%H:%M %b %d, %Y'")

    (defpoll music :interval "2s"
      "playerctl --player=spotify metadata --format '{{ artist }} - {{ title }}' 2>/dev/null || echo ''")

    (defpoll volume :interval "1s"
      "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print substr($2, 1, 4) * 100}'")

    (defpoll workspaces :interval "1s"
      "hyprctl workspaces -j | jq '.[] | select(.windows != 0) | .id' | wc -l")

    (defpoll current_workspace :interval "0.1s"
      "hyprctl activeworkspace -j | jq .id")
  '';

  xdg.configFile."eww/eww.scss".text = ''
    * {
      all: unset;
      font-family: "JetBrains Mono Nerd Font";
      font-size: 14px;
    }

    .bar {
      background-color: rgba(30, 30, 46, 0.8);
      color: #cdd6f4;
      padding: 0px 10px;
    }

    .sidestuff slider {
      all: unset;
      color: #cdd6f4;
    }

    .workspaces {
      background: rgba(49, 50, 68, 0.8);
      border-radius: 10px;
      padding: 0px 10px;
      margin: 5px;
    }

    .music {
      color: #89b4fa;
      background: rgba(49, 50, 68, 0.8);
      border-radius: 10px;
      padding: 0px 10px;
      margin: 5px;
    }

    .metric {
      background: rgba(49, 50, 68, 0.8);
      border-radius: 10px;
      padding: 0px 10px;
      margin: 5px;
    }

    .time {
      color: #f9e2af;
      background: rgba(49, 50, 68, 0.8);
      border-radius: 10px;
      padding: 0px 10px;
      margin: 5px;
    }

    .label {
      color: #cdd6f4;
      padding-right: 10px;
    }

    scale trough {
      all: unset;
      background-color: #313244;
      border-radius: 10px;
      min-height: 3px;
      min-width: 50px;
      margin-left: 5px;
      margin-right: 20px;
    }

    scale highlight {
      all: unset;
      background-color: #89b4fa;
      border-radius: 10px;
      min-height: 3px;
    }

    scale slider {
      all: unset;
      background-color: #89b4fa;
      border-radius: 100%;
      min-height: 15px;
      min-width: 15px;
    }
  '';
}