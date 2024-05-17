{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    prefix = "C-s";
    shell = "${pkgs.oil}/bin/oil";
    terminal = "tmux-256color";
    historyLimit = 100000;
    extraConfig = ''
    bind-key -n C-h select-pane -L
    bind-key -n C-j select-pane -D
    bind-key -n C-k select-pane -U
    bind-key -n C-l select-pane -R

    bind-key - split-window -v -c '#{pane_current_path'
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