{ inputs, pkgs, config, ... }:
{
  xdg.configFile."tmux/plugins/tmux-which-key/config.yaml".text = ''
    command_alias_start_index: 200
    keybindings:
      prefix_table: Space
    title:
      style: align=centre,bold
      prefix: tmux
      prefix_style: fg=green,bold
      position: bottom
    position:
      x: C
      y: C
    custom_variables: {}
    macros: {}
    items:
      - name: Panes
        key: p
        menu:
          - name: Navigate left
            key: h
            command: select-pane -L
          - name: Navigate down
            key: j
            command: select-pane -D
          - name: Navigate up
            key: k
            command: select-pane -U
          - name: Navigate right
            key: l
            command: select-pane -R
          - separator: true
          - name: Split vertical
            key: "-"
            command: split-window -v -c "#{pane_current_path}"
          - name: Split horizontal
            key: \
            command: split-window -h -c "#{pane_current_path}"
          - separator: true
          - name: Break pane
            key: b
            command: break-pane -d
      - name: Windows
        key: w
        menu:
          - name: New window
            key: c
            command: new-window -c "#{pane_current_path}"
          - name: Choose tree
            key: t
            command: choose-tree
      - name: Resize
        key: r
        menu:
          - name: Resize left (2)
            key: h
            command: resize-pane -L 2
          - name: Resize down (1)
            key: j
            command: resize-pane -D 1
          - name: Resize up (1)
            key: k
            command: resize-pane -U 1
          - name: Resize right (2)
            key: l
            command: resize-pane -R 2
          - separator: true
          - name: Resize left (10)
            key: H
            command: resize-pane -L 10
          - name: Resize down (5)
            key: J
            command: resize-pane -D 5
          - name: Resize up (5)
            key: K
            command: resize-pane -U 5
          - name: Resize right (10)
            key: L
            command: resize-pane -R 10
      - name: Session
        key: s
        menu:
          - name: Detach
            key: d
            command: detach-client
          - name: Choose session
            key: s
            command: choose-session
  '';

  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    prefix = "C-s";
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    historyLimit = 10000;

    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = tmux-which-key;
        extraConfig = ''
          set -g @tmux-which-key-xdg-enable 1
        '';
      }
    ];

    extraConfig = ''
      bind-key -n C-h select-pane -L
      bind-key -n C-j select-pane -D
      bind-key -n C-k select-pane -U
      bind-key -n C-l select-pane -R
      bind-key - split-window -v -c '#{pane_current_path}'
      bind-key '\' split-window -h -c '#{pane_current_path}'
      set -g status-bg '#666666'
      set -g status-fg '#aaaaaa'
      set -g status-left-length 50
      # Fine adjustment (1 or 2 cursor cells per bump)
      bind -n S-Left resize-pane -L 2
      bind -n S-Right resize-pane -R 2
      bind -n S-Down resize-pane -D 1
      bind -n S-Up resize-pane -U 1
      # Coarse adjustment (5 or 10 cursor cells per bump)
      bind -n C-Left resize-pane -L 10
      bind -n C-Right resize-pane -R 10
      bind -n C-Down resize-pane -D 5
      bind -n C-Up resize-pane -U 5
      bind c new-window -c "#{pane_current_path}"
      bind-key b break-pane -d
      bind-key C-j choose-tree
    '';
  };
}
