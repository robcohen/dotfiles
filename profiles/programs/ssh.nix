{ inputs, pkgs, config, ... }:
{
  # Don't use programs.ssh - it has a 7-year-old bug where it creates
  # symlinks to immutable Nix store files with wrong permissions.
  # Manage SSH config as a normal file instead.

  home.file.".ssh/config" = {
    text = ''
      Host *
        ForwardAgent no

      Host *.internal *.ts.net
        User user
        IdentityFile ~/.ssh/id_ed25519
        StrictHostKeyChecking yes
        VerifyHostKeyDNS no

      Host *.onion
        CheckHostIP no
        Compression yes
        ProxyCommand ${pkgs.tor}/bin/torify ${pkgs.libressl.nc}/bin/nc %h %p

      Host github.com
        User git
        IdentityFile ~/.ssh/id_ed25519
        ForwardAgent no
        IdentitiesOnly yes
        StrictHostKeyChecking yes
        VerifyHostKeyDNS yes

      Host localhost
        ForwardAgent yes

      Host *
        ForwardAgent no
        AddKeysToAgent yes
        Compression yes
        ServerAliveInterval 60
        ServerAliveCountMax 3
        HashKnownHosts yes
        VisualHostKey yes
        StrictHostKeyChecking ask
        VerifyHostKeyDNS yes
        UserKnownHostsFile ~/.ssh/known_hosts
        ControlMaster auto
        ControlPath ~/.ssh/master-%r@%h:%p
        ControlPersist 10m

        # Security hardening
        ForwardX11 no
        ForwardX11Trusted no
        PermitLocalCommand no
        HostbasedAuthentication no
        PubkeyAuthentication yes

        # Security settings
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
        KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

        # Connection settings
        TCPKeepAlive yes
    '';

    # Break the symlink and copy the file with correct permissions
    onChange = ''
      if [ -L ~/.ssh/config ]; then
        target=$(readlink -f ~/.ssh/config)
        rm ~/.ssh/config
        cp "$target" ~/.ssh/config
        chmod 600 ~/.ssh/config
      fi
    '';
  };
}
