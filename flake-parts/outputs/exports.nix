# Flake exports for use by other flakes (e.g., infra-private)
# Provides nixosModules, commonConfigs, and lib helpers
{ self, inputs, ... }:

{
  flake = {
    # =========================================================================
    # NixOS Modules
    # =========================================================================
    # Usage in consuming flake:
    #   modules = [ dotfiles.nixosModules.sops dotfiles.nixosModules.htpc ];
    nixosModules = {
      # Core modules
      sops = "${self}/modules/sops.nix";
      virtualization = "${self}/modules/virtualization.nix";

      # Service modules
      arr-stack = "${self}/modules/arr-stack.nix";
      jellyfin = "${self}/modules/jellyfin.nix";
      htpc = "${self}/modules/htpc.nix";

      # Networking modules
      tailscale-mullvad = "${self}/modules/tailscale-mullvad.nix";
      travel-router = "${self}/modules/travel-router.nix";

      # Hardware modules
      mt7925 = "${self}/modules/hardware/mt7925.nix";
      thunderbolt-dock = "${self}/modules/hardware/thunderbolt-dock.nix";

      # Platform-specific (Windows config generation)
      wintv = "${self}/modules/wintv.nix";

      # Bundle: all standard NixOS modules
      default = {
        imports = [
          "${self}/modules/sops.nix"
          "${self}/modules/virtualization.nix"
          "${self}/modules/arr-stack.nix"
          "${self}/modules/jellyfin.nix"
          "${self}/modules/htpc.nix"
          "${self}/modules/tailscale-mullvad.nix"
          "${self}/modules/travel-router.nix"
        ];
      };
    };

    # =========================================================================
    # Common Configurations
    # =========================================================================
    # Usage:
    #   modules = [ dotfiles.commonConfigs.base dotfiles.commonConfigs.security ];
    commonConfigs = {
      # Individual configs
      base = "${self}/hosts/common/base.nix";
      security = "${self}/hosts/common/security.nix";
      tpm = "${self}/hosts/common/tpm.nix";
      sddm = "${self}/hosts/common/sddm.nix";
      swap = "${self}/hosts/common/swap.nix";

      # Bundle: full desktop config
      desktop = {
        imports = [
          "${self}/hosts/common/base.nix"
          "${self}/hosts/common/security.nix"
          "${self}/hosts/common/tpm.nix"
          "${self}/hosts/common/sddm.nix"
          "${self}/hosts/common/swap.nix"
        ];
      };

      # Bundle: minimal server config
      server = {
        imports = [
          "${self}/hosts/common/base.nix"
          "${self}/hosts/common/security.nix"
        ];
      };
    };

    # =========================================================================
    # Library Functions
    # =========================================================================
    # Usage:
    #   dotfiles.lib.constants
    #   dotfiles.lib.mkWintvGenerators { inherit pkgs; }
    lib = {
      # Host constants and defaults
      constants = import "${self}/lib/constants.nix";

      # WinTV config generators (for Windows host)
      mkWintvGenerators = { pkgs }:
        import "${self}/lib/wintv-generators.nix" {
          lib = pkgs.lib;
          inherit pkgs;
        };
    };
  };
}
