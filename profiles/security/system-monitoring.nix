{ config, pkgs, lib, hostType, hostFeatures, ... }:

let
  hasFeature = feature: builtins.elem feature hostFeatures;
  isDesktop = hostType == "desktop";
in {
  # Security monitoring tools
  home.packages = with pkgs; [
    rkhunter        # Rootkit scanner
    chkrootkit      # Another rootkit scanner
    lynis           # Security auditing tool
    vulnix          # Nix vulnerability scanner
    nmap            # Network scanner
    netcat-gnu      # Network utility
    tcpdump         # Network packet analyzer
    wireshark       # Network protocol analyzer (GUI)
    aide            # File integrity checker
  ];

  # System security audit script
  home.file.".local/bin/security-scan" = {
    text = ''
      #!/bin/bash
      # Comprehensive security scanning
      set -euo pipefail
      
      echo "🔍 System Security Scan"
      echo "======================"
      
      # Check for updates
      echo ""
      echo "📦 System Updates:"
      if command -v nix-channel >/dev/null 2>&1; then
        echo "NixOS system - checking flake updates..."
        cd ~/Documents/dotfiles && git fetch origin
        if git status | grep -q "behind"; then
          echo "⚠️  Dotfiles repository has updates available"
        else
          echo "✅ Dotfiles up to date"
        fi
      fi
      
      # Network security check
      echo ""
      echo "🌐 Network Security:"
      echo "Open ports on localhost:"
      netstat -tlnp 2>/dev/null | grep LISTEN | head -10
      
      # Process monitoring
      echo ""
      echo "⚙️  Process Security:"
      echo "Processes with network connections:"
      netstat -tulnp 2>/dev/null | grep -E ":(22|80|443|8080)" | head -5
      
      # File permissions audit
      echo ""
      echo "📁 File Security:"
      echo "World-writable files in home:"
      find "$HOME" -type f -perm -002 2>/dev/null | head -5 || echo "None found"
      
      # SSH security
      echo ""
      echo "🔑 SSH Security:"
      if [[ -f ~/.ssh/authorized_keys ]]; then
        echo "Authorized keys count: $(wc -l < ~/.ssh/authorized_keys)"
      else
        echo "No authorized_keys file"
      fi
      
      # GPG security
      echo ""
      echo "🔐 GPG Security:"
      if command -v gpg >/dev/null 2>&1; then
        echo "GPG keys:"
        gpg --list-secret-keys --keyid-format short 2>/dev/null | grep -c "^sec" || echo "0"
      fi
      
      # Nix security
      echo ""
      echo "📋 Nix Security:"
      if command -v vulnix >/dev/null 2>&1; then
        echo "Running vulnerability scan..."
        vulnix --system 2>/dev/null | head -5 || echo "No vulnerabilities found"
      fi
      
      echo ""
      echo "✅ Security scan complete"
      echo "💡 Run 'lynis audit system' for detailed security audit"
    '';
    executable = true;
  };

  # File integrity monitoring
  home.file.".local/bin/integrity-check" = {
    text = ''
      #!/bin/bash
      # File integrity monitoring for important files
      set -euo pipefail
      
      INTEGRITY_DIR="$HOME/.integrity"
      mkdir -p "$INTEGRITY_DIR"
      
      # Important files to monitor
      IMPORTANT_FILES=(
        "$HOME/.ssh/authorized_keys"
        "$HOME/.ssh/config"
        "$HOME/.gnupg/gpg.conf"
        "$HOME/.gitconfig"
        "$HOME/.bashrc"
        "$HOME/.zshrc"
      )
      
      case "''${1:-check}" in
        "init"|"baseline")
          echo "🔒 Creating integrity baseline..."
          for file in "''${IMPORTANT_FILES[@]}"; do
            if [[ -f "$file" ]]; then
              HASH=$(sha256sum "$file" | cut -d' ' -f1)
              echo "$file:$HASH" >> "$INTEGRITY_DIR/baseline.txt"
              echo "Added: $(basename "$file")"
            fi
          done
          echo "✅ Baseline created in $INTEGRITY_DIR/baseline.txt"
          ;;
          
        "check"|"verify")
          if [[ ! -f "$INTEGRITY_DIR/baseline.txt" ]]; then
            echo "❌ No baseline found. Run 'integrity-check init' first"
            exit 1
          fi
          
          echo "🔍 Checking file integrity..."
          CHANGES=0
          
          while IFS=: read -r file expected_hash; do
            if [[ -f "$file" ]]; then
              current_hash=$(sha256sum "$file" | cut -d' ' -f1)
              if [[ "$current_hash" != "$expected_hash" ]]; then
                echo "⚠️  CHANGED: $file"
                CHANGES=$((CHANGES + 1))
              fi
            else
              echo "❌ MISSING: $file"
              CHANGES=$((CHANGES + 1))
            fi
          done < "$INTEGRITY_DIR/baseline.txt"
          
          if [[ $CHANGES -eq 0 ]]; then
            echo "✅ All monitored files are unchanged"
          else
            echo "⚠️  $CHANGES file(s) have changed or are missing"
          fi
          ;;
          
        *)
          echo "Usage: integrity-check [init|check]"
          echo ""
          echo "Commands:"
          echo "  init   Create integrity baseline"
          echo "  check  Verify files against baseline"
          ;;
      esac
    '';
    executable = true;
  };

  # Network monitoring helper
  home.file.".local/bin/network-monitor" = {
    text = ''
      #!/bin/bash
      # Simple network monitoring
      set -euo pipefail
      
      echo "🌐 Network Security Monitor"
      echo "=========================="
      
      # Active connections
      echo ""
      echo "Active network connections:"
      netstat -tuln | grep LISTEN | while read line; do
        port=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
        echo "  Port $port: $(echo "$line" | awk '{print $1}')"
      done
      
      # Recent connection attempts (if available)
      echo ""
      echo "Recent SSH attempts (last 10):"
      if [[ -f /var/log/auth.log ]]; then
        grep "sshd" /var/log/auth.log 2>/dev/null | tail -5 || echo "  No SSH logs accessible"
      else
        echo "  No auth log accessible"
      fi
      
      # DNS resolution test
      echo ""
      echo "DNS Security Test:"
      for domain in google.com github.com; do
        if nslookup "$domain" >/dev/null 2>&1; then
          echo "  ✅ $domain resolves correctly"
        else
          echo "  ❌ $domain resolution failed"
        fi
      done
      
      # Basic port scan of localhost
      echo ""
      echo "Localhost port scan (common ports):"
      for port in 22 80 443 8080; do
        if timeout 1 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
          echo "  Port $port: OPEN"
        fi
      done
    '';
    executable = true;
  };

  # Automated security maintenance
  systemd.user.services.security-maintenance = lib.mkIf isDesktop {
    Unit = {
      Description = "Weekly security maintenance";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${config.home.homeDirectory}/.local/bin/security-scan > ${config.home.homeDirectory}/.cache/security-scan.log 2>&1'";
    };
  };

  systemd.user.timers.security-maintenance = lib.mkIf isDesktop {
    Unit = {
      Description = "Weekly security maintenance timer";
    };
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}