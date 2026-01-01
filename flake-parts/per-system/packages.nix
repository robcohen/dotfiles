# Package outputs
# ISOs, VMs, and wintv-config
{
  inputs,
  self,
  ...
}:

let
  inherit (inputs)
    stable-nixpkgs
    sops-nix
    nixos-generators
    microvm
    ;
in
{
  perSystem =
    {
      system,
      pkgs,
      lib,
      mkSpecialArgs,
      ...
    }:
    let
      # WinTV configuration generators
      wintvGenerators = import "${self}/lib/wintv-generators.nix" {
        lib = pkgs.lib;
        inherit pkgs;
      };

      wintvConfig = (import "${self}/hosts/wintv/config.nix" { lib = pkgs.lib; }).wintv;

      # Function to generate ISO/VM for any host
      mkImage =
        hostConfig: format:
        nixos-generators.nixosGenerate {
          inherit system format;
          specialArgs = mkSpecialArgs;
          modules = [
            hostConfig
            sops-nix.nixosModules.sops
            "${self}/modules/sops.nix"
            microvm.nixosModules.host
          ];
        };

      # Function to generate live ISO with SSH access
      mkLiveISO =
        hostConfig:
        nixos-generators.nixosGenerate {
          inherit system;
          specialArgs = mkSpecialArgs;
          modules = [
            hostConfig
            sops-nix.nixosModules.sops
            "${self}/modules/sops.nix"
            microvm.nixosModules.host
            (
              { ... }:
              {
                services.openssh.enable = true;
              }
            )
          ];
          format = "iso";
        };
    in
    {
      packages = {
        # =======================================================================
        # WinTV - Declarative Windows + Podman configuration
        # =======================================================================
        # Build: nix build .#wintv-config
        # Deploy: Copy result/ to Windows and run .\deploy.ps1 -Apply
        wintv-config = wintvGenerators.buildWintvConfig wintvConfig;

        # Live ISOs for each host
        slax-live-iso = mkLiveISO "${self}/hosts/slax/configuration.nix";
        brix-live-iso = mkLiveISO "${self}/hosts/brix/configuration.nix";

        # VM images for each host
        slax-vm = mkImage "${self}/hosts/slax/configuration.nix" "vm";
        brix-vm = mkImage "${self}/hosts/brix/configuration.nix" "vm";

        # Generic emergency recovery ISO
        # =======================================================================
        # Build with custom credentials (recommended):
        #   EMERGENCY_SSH_KEY="<your-ssh-pubkey>" nix build .#emergency-iso
        #   EMERGENCY_PASSWORD_HASH="$(mkpasswd -m sha-512)" nix build .#emergency-iso
        #
        # Without env vars: SSH enabled, no password (SSH key required)
        # =======================================================================
        emergency-iso = nixos-generators.nixosGenerate {
          inherit system;
          specialArgs = mkSpecialArgs;
          modules = [
            "${self}/hosts/common/base.nix"
            sops-nix.nixosModules.sops
            "${self}/modules/sops.nix"
            microvm.nixosModules.host
            (
              {
                config,
                lib,
                pkgs,
                ...
              }:
              let
                envKey = builtins.getEnv "EMERGENCY_SSH_KEY";
                envPasswordHash = builtins.getEnv "EMERGENCY_PASSWORD_HASH";
                # Validate SSH key format (must start with valid key type)
                validSshKeyPrefixes = [
                  "ssh-ed25519"
                  "ssh-rsa"
                  "ssh-ecdsa"
                  "ecdsa-sha2-"
                  "sk-ssh-ed25519"
                  "sk-ecdsa-sha2-"
                ];
                isValidSshKey = key: key == "" || lib.any (prefix: lib.hasPrefix prefix key) validSshKeyPrefixes;
                sshKeyValid = isValidSshKey envKey;
              in
              {
                # Assert SSH key format is valid if provided
                assertions = [
                  {
                    assertion = sshKeyValid;
                    message = "EMERGENCY_SSH_KEY has invalid format. Must start with: ${lib.concatStringsSep ", " validSshKeyPrefixes}";
                  }
                ];
                services.openssh = {
                  enable = true;
                  settings.PermitRootLogin = if envKey != "" then "prohibit-password" else "yes";
                };
                users.users.root = {
                  openssh.authorizedKeys.keys = lib.optional (envKey != "" && sshKeyValid) envKey;
                  # Use env var hash if provided, otherwise no password (SSH key required)
                  initialHashedPassword = lib.mkIf (envPasswordHash != "") envPasswordHash; # noqa: secret
                };
                environment.etc."motd".text = ''
                  ════════════════════════════════════════════════════════════════
                    EMERGENCY RECOVERY ISO
                  ${lib.optionalString (
                    envPasswordHash != ""
                  ) "  Password was set at build time - change with: passwd"}
                  ${lib.optionalString (envKey != "") "  SSH key configured - password login disabled"}
                  ${lib.optionalString (
                    envKey == "" && envPasswordHash == ""
                  ) "  WARNING: No credentials configured! Add SSH key or rebuild with password."}
                  ════════════════════════════════════════════════════════════════
                '';
              }
            )
          ];
          format = "iso";
        };
      };
    };
}
