{ config, pkgs, lib, ... }:

{
  imports = [
    ./infrastructure.nix      # Infrastructure tools
    ./direnv-infrastructure.nix  # Auto-loading infrastructure environment
  ];
  # Development-specific programs
  programs = {
    # Enhanced direnv already configured
    nix-index.enable = true;
    
    # Version control enhancements
    git = {
      aliases = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";
        pushf = "push --force-with-lease";
        graph = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
    };
  };

  # Development environment setup
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
  ];

  # Development directories
  xdg.userDirs.extraConfig = {
    XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
    XDG_REPOS_DIR = "${config.home.homeDirectory}/Repositories";
  };

  # Development-specific dotfiles
  home.file = {
    ".editorconfig".text = ''
      root = true

      [*]
      charset = utf-8
      end_of_line = lf
      insert_final_newline = true
      trim_trailing_whitespace = true
      indent_style = space
      indent_size = 2

      [*.{py,rs}]
      indent_size = 4

      [*.go]
      indent_style = tab

      [Makefile]
      indent_style = tab
    '';
    
    ".gdbinit".text = ''
      set print pretty on
      set print array on
      set print array-indexes on
      set python print-stack full
    '';
  };
}