{ pkgs, ... }:

{
  # SSH hardening
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      Protocol = 2;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    # Global Syncthing ports for desktop hosts
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [ 22000 21027 ];
    # Deny ping requests
    allowPing = false;
  };

  # Fail2ban for intrusion detection
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";
      factor = "2";
    };
  };

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "github:robcxyz/dotfiles";
  };

  # AppArmor security framework
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
  };

  # Kernel security hardening
  boot.kernel.sysctl = {
    # Network security
    "net.ipv4.conf.all.send_redirects" = false;
    "net.ipv4.conf.default.send_redirects" = false;
    "net.ipv4.conf.all.accept_redirects" = false;
    "net.ipv4.conf.default.accept_redirects" = false;
    "net.ipv4.conf.all.accept_source_route" = false;
    "net.ipv4.conf.default.accept_source_route" = false;
    "net.ipv4.icmp_echo_ignore_broadcasts" = true;
    "net.ipv4.icmp_ignore_bogus_error_responses" = true;
    "net.ipv4.tcp_syncookies" = true;
    
    # Memory protection
    "kernel.dmesg_restrict" = true;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
  };

  # Secure boot (when available)
  boot.loader.systemd-boot.editor = false;
  
  # Password policy
  security.pam.loginLimits = [
    { domain = "*"; type = "hard"; item = "maxlogins"; value = "3"; }
  ];
}