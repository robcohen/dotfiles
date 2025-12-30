{ config, lib, pkgs, ... }:

{
  options.security.autoUpgrade.flakeUrl = lib.mkOption {
    type = lib.types.str;
    default = "github:robcxyz/dotfiles";
    description = "Flake URL for automatic security updates";
  };

  config = {
  # SSH hardening - best practices
  services.openssh = {
    enable = true;
    # Only Ed25519 host keys (modern, secure, fast)
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      # Authentication
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
      AuthenticationMethods = "publickey";
      MaxAuthTries = 3;
      MaxSessions = 10;
      PermitEmptyPasswords = false;

      # Session
      X11Forwarding = false;
      AllowTcpForwarding = false;
      AllowAgentForwarding = false;
      AllowStreamLocalForwarding = false;
      GatewayPorts = "no";
      PermitTunnel = "no";
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      TCPKeepAlive = false;  # Use ClientAlive instead (encrypted)
      LoginGraceTime = 30;

      # Modern cryptography only
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];
      KexAlgorithms = [
        "sntrup761x25519-sha512@openssh.com"  # Post-quantum hybrid
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group16-sha512"
        "diffie-hellman-group18-sha512"
      ];

      # Logging
      LogLevel = "VERBOSE";

      # Misc hardening
      StrictModes = true;
      UseDns = false;
      PermitUserEnvironment = false;
      Compression = false;
      PrintLastLog = true;
    };
    # Restrict SSH to users in wheel group
    extraConfig = ''
      AllowGroups wheel
    '';
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
    flake = config.security.autoUpgrade.flakeUrl;
  };

  # AppArmor security framework (relaxed configuration)
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = false;  # Don't kill unconfined processes
    packages = [ pkgs.apparmor-profiles ];  # Basic system profiles
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
  };  # Close config block
}
