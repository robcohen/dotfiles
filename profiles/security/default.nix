{ config, pkgs, lib, hostType, hostFeatures, ... }:

{
  imports = [
    ./advanced-gpg.nix
    ./advanced-ssh.nix  
    ./system-monitoring.nix
  ];

  # Core security packages
  home.packages = with pkgs; [
    age               # Modern encryption
    sops              # Secrets operations
  ];

  # Security shell aliases
  home.shellAliases = {
    security-scan = "~/.local/bin/security-scan";
    integrity-check = "~/.local/bin/integrity-check check";
    network-monitor = "~/.local/bin/network-monitor";
    gpg-verify = "~/.local/bin/gpg-verify";
    ssh-audit = "~/.local/bin/ssh-audit-local";
  };

  # Security documentation
  home.file.".config/security/README.md".text = ''
    # Security Tools and Utilities
    
    ## Available Commands
    
    ### System Security
    - `security-scan` - Comprehensive system security check
    - `integrity-check` - File integrity monitoring
    - `network-monitor` - Network security monitoring
    
    ### Cryptographic Tools
    - `gpg-verify` - GPG key security verification
    - `gpg-backup` - Secure GPG key backup
    - `ssh-audit` - SSH client security audit
    - `ssh-rotate-keys` - SSH key rotation helper
    - `secure-scp` - Secure file transfer with integrity checking
    
    ## Security Maintenance
    
    ### Weekly Tasks
    - Run `security-scan` to check for issues
    - Update system packages
    - Review log files for anomalies
    
    ### Monthly Tasks  
    - Run `integrity-check init` to update baselines
    - Audit user accounts and permissions
    - Review and rotate credentials as needed
    
    ### Quarterly Tasks
    - Full `lynis audit system` security audit
    - Review and update security policies
    - Test backup and recovery procedures
    
    ## Emergency Procedures
    
    ### Suspected Compromise
    1. Disconnect from network immediately
    2. Run `rkhunter --check` for rootkit scan
    3. Check `integrity-check` for file modifications
    4. Review recent login attempts and processes
    5. Contact security team if in enterprise environment
    
    ### Key Compromise
    1. Revoke compromised keys immediately
    2. Generate new keys with `ssh-rotate-keys`
    3. Update authorized_keys on all systems
    4. Review access logs for unauthorized usage
  '';
}