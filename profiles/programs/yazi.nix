{ config, pkgs, lib, ... }:

{
  # Yazi - Modern terminal file manager
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;

    settings = {
      manager = {
        ratio = [ 1 4 3 ];
        sort_by = "natural";
        sort_sensitive = false;
        sort_reverse = false;
        sort_dir_first = true;
        linemode = "size";
        show_hidden = false;
        show_symlink = true;
      };

      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        cache_dir = "";
        image_filter = "triangle";
        image_quality = 75;
        sixel_fraction = 15;
        ueberzug_scale = 1;
        ueberzug_offset = [ 0 0 0 0 ];
      };

      opener = {
        edit = [
          { run = ''nvim "$@"''; block = true; for = "unix"; }
        ];
        open = [
          { run = ''xdg-open "$@"''; desc = "Open"; for = "linux"; }
        ];
        reveal = [
          { run = ''xdg-open "$(dirname "$0")"''; desc = "Reveal"; for = "linux"; }
        ];
        extract = [
          { run = ''unar "$1"''; desc = "Extract here"; for = "unix"; }
        ];
        play = [
          { run = ''mpv "$@"''; orphan = true; for = "unix"; }
        ];
      };

      open = {
        rules = [
          { name = "*/"; use = [ "edit" "open" "reveal" ]; }

          { mime = "text/*"; use = [ "edit" "reveal" ]; }
          { mime = "image/*"; use = [ "open" "reveal" ]; }
          { mime = "video/*"; use = [ "play" "reveal" ]; }
          { mime = "audio/*"; use = [ "play" "reveal" ]; }
          { mime = "inode/x-empty"; use = [ "edit" "reveal" ]; }

          { mime = "application/json"; use = [ "edit" "reveal" ]; }
          { mime = "*/javascript"; use = [ "edit" "reveal" ]; }

          { mime = "application/zip"; use = [ "extract" "reveal" ]; }
          { mime = "application/gzip"; use = [ "extract" "reveal" ]; }
          { mime = "application/x-tar"; use = [ "extract" "reveal" ]; }
          { mime = "application/x-bzip"; use = [ "extract" "reveal" ]; }
          { mime = "application/x-bzip2"; use = [ "extract" "reveal" ]; }
          { mime = "application/x-7z-compressed"; use = [ "extract" "reveal" ]; }
          { mime = "application/x-rar"; use = [ "extract" "reveal" ]; }
          { mime = "application/xz"; use = [ "extract" "reveal" ]; }

          { mime = "*"; use = [ "open" "reveal" ]; }
        ];
      };
    };

    keymap = {
      manager.keymap = [
        # Navigation
        { on = [ "k" ]; run = "arrow -1"; desc = "Move cursor up"; }
        { on = [ "j" ]; run = "arrow 1"; desc = "Move cursor down"; }
        { on = [ "<Up>" ]; run = "arrow -1"; desc = "Move cursor up"; }
        { on = [ "<Down>" ]; run = "arrow 1"; desc = "Move cursor down"; }
        { on = [ "<C-u>" ]; run = "arrow -50%"; desc = "Move cursor up half page"; }
        { on = [ "<C-d>" ]; run = "arrow 50%"; desc = "Move cursor down half page"; }
        { on = [ "h" ]; run = "leave"; desc = "Go back to parent directory"; }
        { on = [ "l" ]; run = "enter"; desc = "Enter the child directory"; }
        { on = [ "<Left>" ]; run = "leave"; desc = "Go back to parent directory"; }
        { on = [ "<Right>" ]; run = "enter"; desc = "Enter the child directory"; }
        { on = [ "<Enter>" ]; run = "open"; desc = "Open the selected files"; }
        { on = [ "<C-Enter>" ]; run = "open --interactive"; desc = "Open interactively"; }
        { on = [ "g" "g" ]; run = "arrow -99999999"; desc = "Move cursor to top"; }
        { on = [ "G" ]; run = "arrow 99999999"; desc = "Move cursor to bottom"; }

        # Selection
        { on = [ "<Space>" ]; run = [ "select --state=none" "arrow 1" ]; desc = "Toggle selection"; }
        { on = [ "v" ]; run = "visual_mode"; desc = "Enter visual mode"; }
        { on = [ "V" ]; run = "visual_mode --unset"; desc = "Enter visual mode (unset)"; }
        { on = [ "<C-a>" ]; run = "select_all --state=true"; desc = "Select all files"; }
        { on = [ "<C-r>" ]; run = "select_all --state=none"; desc = "Inverse selection"; }

        # Operations
        { on = [ "o" ]; run = "open"; desc = "Open files"; }
        { on = [ "O" ]; run = "open --interactive"; desc = "Open interactively"; }
        { on = [ "y" ]; run = "yank"; desc = "Yank files (copy)"; }
        { on = [ "x" ]; run = "yank --cut"; desc = "Yank files (cut)"; }
        { on = [ "p" ]; run = "paste"; desc = "Paste files"; }
        { on = [ "P" ]; run = "paste --force"; desc = "Paste files (overwrite)"; }
        { on = [ "-" ]; run = "link"; desc = "Symlink absolute path"; }
        { on = [ "_" ]; run = "link --relative"; desc = "Symlink relative path"; }
        { on = [ "d" ]; run = "remove"; desc = "Trash files"; }
        { on = [ "D" ]; run = "remove --permanently"; desc = "Delete files permanently"; }
        { on = [ "a" ]; run = "create"; desc = "Create file or directory"; }
        { on = [ "r" ]; run = "rename --cursor=before_ext"; desc = "Rename"; }
        { on = [ ";" ]; run = "shell"; desc = "Run a shell command"; }
        { on = [ ":" ]; run = "shell --block"; desc = "Run a shell command (block)"; }
        { on = [ "." ]; run = "hidden toggle"; desc = "Toggle hidden files"; }
        { on = [ "s" ]; run = "search fd"; desc = "Search files by name"; }
        { on = [ "S" ]; run = "search rg"; desc = "Search files by content"; }
        { on = [ "<C-s>" ]; run = "search none"; desc = "Cancel search"; }
        { on = [ "z" ]; run = "jump zoxide"; desc = "Jump to a directory using zoxide"; }
        { on = [ "Z" ]; run = "jump fzf"; desc = "Jump to a directory using fzf"; }

        # Copy paths
        { on = [ "c" "c" ]; run = "copy path"; desc = "Copy file path"; }
        { on = [ "c" "d" ]; run = "copy dirname"; desc = "Copy directory path"; }
        { on = [ "c" "f" ]; run = "copy filename"; desc = "Copy filename"; }
        { on = [ "c" "n" ]; run = "copy name_without_ext"; desc = "Copy filename without extension"; }

        # Filtering/sorting
        { on = [ "," ]; run = "sort modified --dir-first"; desc = "Sort by modified time"; }

        # Tabs
        { on = [ "t" ]; run = "tab_create --current"; desc = "Create new tab"; }
        { on = [ "1" ]; run = "tab_switch 0"; desc = "Switch to tab 1"; }
        { on = [ "2" ]; run = "tab_switch 1"; desc = "Switch to tab 2"; }
        { on = [ "3" ]; run = "tab_switch 2"; desc = "Switch to tab 3"; }
        { on = [ "4" ]; run = "tab_switch 3"; desc = "Switch to tab 4"; }
        { on = [ "[" ]; run = "tab_switch -1 --relative"; desc = "Switch to previous tab"; }
        { on = [ "]" ]; run = "tab_switch 1 --relative"; desc = "Switch to next tab"; }
        { on = [ "{" ]; run = "tab_swap -1"; desc = "Swap with previous tab"; }
        { on = [ "}" ]; run = "tab_swap 1"; desc = "Swap with next tab"; }

        # Tasks
        { on = [ "w" ]; run = "tasks_show"; desc = "Show task manager"; }

        # Goto
        { on = [ "g" "h" ]; run = "cd ~"; desc = "Go to home directory"; }
        { on = [ "g" "c" ]; run = "cd ~/.config"; desc = "Go to config directory"; }
        { on = [ "g" "d" ]; run = "cd ~/Downloads"; desc = "Go to downloads"; }
        { on = [ "g" "p" ]; run = "cd ~/Projects"; desc = "Go to projects"; }
        { on = [ "g" "t" ]; run = "cd /tmp"; desc = "Go to tmp"; }

        # Help
        { on = [ "~" ]; run = "help"; desc = "Open help"; }
        { on = [ "q" ]; run = "quit"; desc = "Quit"; }
        { on = [ "Q" ]; run = "quit --no-cwd-file"; desc = "Quit without changing directory"; }
        { on = [ "<Esc>" ]; run = "escape"; desc = "Exit visual mode / cancel"; }
      ];

      tasks.keymap = [
        { on = [ "<Esc>" ]; run = "close"; desc = "Close task manager"; }
        { on = [ "q" ]; run = "close"; desc = "Close task manager"; }
        { on = [ "w" ]; run = "close"; desc = "Close task manager"; }
        { on = [ "k" ]; run = "arrow -1"; desc = "Move cursor up"; }
        { on = [ "j" ]; run = "arrow 1"; desc = "Move cursor down"; }
        { on = [ "<Enter>" ]; run = "inspect"; desc = "Inspect task"; }
        { on = [ "x" ]; run = "cancel"; desc = "Cancel task"; }
        { on = [ "~" ]; run = "help"; desc = "Open help"; }
      ];

      select.keymap = [
        { on = [ "<Esc>" ]; run = "close"; desc = "Cancel selection"; }
        { on = [ "q" ]; run = "close"; desc = "Cancel selection"; }
        { on = [ "<Enter>" ]; run = "close --submit"; desc = "Submit selection"; }
        { on = [ "k" ]; run = "arrow -1"; desc = "Move cursor up"; }
        { on = [ "j" ]; run = "arrow 1"; desc = "Move cursor down"; }
        { on = [ "~" ]; run = "help"; desc = "Open help"; }
      ];

      input.keymap = [
        { on = [ "<Esc>" ]; run = "close"; desc = "Cancel input"; }
        { on = [ "<Enter>" ]; run = "close --submit"; desc = "Submit input"; }
        { on = [ "<C-c>" ]; run = "close"; desc = "Cancel input"; }

        # Mode switching
        { on = [ "i" ]; run = "insert"; desc = "Enter insert mode"; }
        { on = [ "a" ]; run = "insert --append"; desc = "Enter append mode"; }
        { on = [ "I" ]; run = [ "move -999" "insert" ]; desc = "Insert at start"; }
        { on = [ "A" ]; run = [ "move 999" "insert --append" ]; desc = "Append at end"; }
        { on = [ "v" ]; run = "visual"; desc = "Enter visual mode"; }

        # Navigation
        { on = [ "h" ]; run = "move -1"; desc = "Move cursor left"; }
        { on = [ "l" ]; run = "move 1"; desc = "Move cursor right"; }
        { on = [ "0" ]; run = "move -999"; desc = "Move to start"; }
        { on = [ "$" ]; run = "move 999"; desc = "Move to end"; }
        { on = [ "<Left>" ]; run = "move -1"; desc = "Move cursor left"; }
        { on = [ "<Right>" ]; run = "move 1"; desc = "Move cursor right"; }

        # Deletion
        { on = [ "<Backspace>" ]; run = "backspace"; desc = "Delete previous character"; }
        { on = [ "<Delete>" ]; run = "backspace --under"; desc = "Delete character under cursor"; }
        { on = [ "<C-u>" ]; run = "kill bol"; desc = "Kill to beginning of line"; }
        { on = [ "<C-k>" ]; run = "kill eol"; desc = "Kill to end of line"; }
        { on = [ "<C-w>" ]; run = "kill backward"; desc = "Kill previous word"; }

        # Cut/Yank/Paste
        { on = [ "d" ]; run = "delete --cut"; desc = "Cut selection"; }
        { on = [ "y" ]; run = "yank"; desc = "Yank selection"; }
        { on = [ "p" ]; run = "paste"; desc = "Paste after cursor"; }
        { on = [ "P" ]; run = "paste --before"; desc = "Paste before cursor"; }

        # Undo/Redo
        { on = [ "u" ]; run = "undo"; desc = "Undo"; }
        { on = [ "<C-r>" ]; run = "redo"; desc = "Redo"; }

        # Help
        { on = [ "~" ]; run = "help"; desc = "Open help"; }
      ];

      help.keymap = [
        { on = [ "<Esc>" ]; run = "close"; desc = "Close help"; }
        { on = [ "q" ]; run = "close"; desc = "Close help"; }
        { on = [ "k" ]; run = "arrow -1"; desc = "Move cursor up"; }
        { on = [ "j" ]; run = "arrow 1"; desc = "Move cursor down"; }
        { on = [ "/" ]; run = "filter"; desc = "Filter"; }
      ];
    };

    theme = {
      manager = {
        cwd = { fg = "#89b4fa"; };
        hovered = { fg = "#1e1e2e"; bg = "#89b4fa"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "#f9e2af"; italic = true; };
        find_position = { fg = "#f5c2e7"; bg = "reset"; italic = true; };
        marker_selected = { fg = "#a6e3a1"; bg = "#a6e3a1"; };
        marker_copied = { fg = "#f9e2af"; bg = "#f9e2af"; };
        marker_cut = { fg = "#f38ba8"; bg = "#f38ba8"; };
        tab_active = { fg = "#1e1e2e"; bg = "#89b4fa"; };
        tab_inactive = { fg = "#cdd6f4"; bg = "#45475a"; };
        tab_width = 1;
        border_symbol = "│";
        border_style = { fg = "#45475a"; };
      };

      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "#45475a"; bg = "#45475a"; };
        mode_normal = { fg = "#1e1e2e"; bg = "#89b4fa"; bold = true; };
        mode_select = { fg = "#1e1e2e"; bg = "#a6e3a1"; bold = true; };
        mode_unset = { fg = "#1e1e2e"; bg = "#f5c2e7"; bold = true; };
        progress_label = { fg = "#cdd6f4"; bold = true; };
        progress_normal = { fg = "#89b4fa"; bg = "#45475a"; };
        progress_error = { fg = "#f38ba8"; bg = "#45475a"; };
        permissions_t = { fg = "#89b4fa"; };
        permissions_r = { fg = "#f9e2af"; };
        permissions_w = { fg = "#f38ba8"; };
        permissions_x = { fg = "#a6e3a1"; };
        permissions_s = { fg = "#6c7086"; };
      };

      input = {
        border = { fg = "#89b4fa"; };
        title = {};
        value = {};
        selected = { reversed = true; };
      };

      select = {
        border = { fg = "#89b4fa"; };
        active = { fg = "#f5c2e7"; };
        inactive = {};
      };

      tasks = {
        border = { fg = "#89b4fa"; };
        title = {};
        hovered = { underline = true; };
      };

      which = {
        mask = { bg = "#313244"; };
        cand = { fg = "#94e2d5"; };
        rest = { fg = "#9399b2"; };
        desc = { fg = "#f5c2e7"; };
        separator = " ";
        separator_style = { fg = "#585b70"; };
      };

      help = {
        on = { fg = "#f5c2e7"; };
        exec = { fg = "#94e2d5"; };
        desc = { fg = "#9399b2"; };
        hovered = { bg = "#585b70"; bold = true; };
        footer = { fg = "#45475a"; bg = "#cdd6f4"; };
      };

      filetype = {
        rules = [
          { mime = "image/*"; fg = "#94e2d5"; }
          { mime = "video/*"; fg = "#f9e2af"; }
          { mime = "audio/*"; fg = "#f9e2af"; }
          { mime = "application/zip"; fg = "#f5c2e7"; }
          { mime = "application/gzip"; fg = "#f5c2e7"; }
          { mime = "application/x-tar"; fg = "#f5c2e7"; }
          { mime = "application/x-bzip"; fg = "#f5c2e7"; }
          { mime = "application/x-bzip2"; fg = "#f5c2e7"; }
          { mime = "application/x-7z-compressed"; fg = "#f5c2e7"; }
          { mime = "application/x-rar"; fg = "#f5c2e7"; }
          { mime = "application/xz"; fg = "#f5c2e7"; }
          { name = "*"; fg = "#cdd6f4"; }
          { name = "*/"; fg = "#89b4fa"; }
        ];
      };
    };
  };

  # Dependencies for yazi
  home.packages = with pkgs; [
    unar        # Archive extraction
    ffmpegthumbnailer  # Video thumbnails
    poppler     # PDF preview
    fd          # File finding
    ripgrep     # Content search
    fzf         # Fuzzy finder
    zoxide      # Directory jumping
    jq          # JSON preview
    imagemagick # Image transformations
  ];
}
