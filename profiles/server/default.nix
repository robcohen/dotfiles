{ config, pkgs, lib, ... }:

{
  # Server-specific programs
  programs = {
    # Enhanced shell for servers
    tmux.enable = lib.mkDefault true;
    
    # System monitoring
    htop.enable = true;
    btop.enable = true;
  };

  # Server-specific packages  
  home.packages = with pkgs; [
    # Network tools
    netcat-gnu
    nmap
    tcpdump
    
    # System monitoring
    iotop
    dstat
    
    # Text processing
    jq
    yq
  ];
}