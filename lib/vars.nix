let
  # Try to import secrets.nix, fallback to defaults if not found
  secrets = if builtins.pathExists ../secrets.nix 
    then import ../secrets.nix 
    else {};
    
  # Merge secrets with defaults
  secretUser = secrets.user or {};
  secretDomains = secrets.domains or {};
in
{
  user = {
    name = "user";
    home = "/home/user";
    email = secretUser.email or "user@example.com";
    realName = secretUser.realName or "Example User";
    githubUsername = secretUser.githubUsername or "example-user";
    signingKey = secretUser.signingKey or "~/.ssh/id_bip39_ed25519.pub";
  };

  domains = {
    primary = secretDomains.primary or "example.com";
    vpn = secretDomains.vpn or "vpn.example.com";
    internal = secretDomains.internal or "internal.example.com";
  };
  
  hosts = {
    brix = {
      swapPath = "/swapfile";
      swapSize = 32 * 1024;
      homeManagerStateVersion = "23.11";
      type = "desktop";
      features = [ "gaming" "development" "multimedia" ];
    };
    slax = {
      swapPath = "/var/lib/swapfile";
      swapSize = 32 * 1024;
      homeManagerStateVersion = "23.11";
      type = "desktop";
      features = [ "development" "multimedia" ];
    };
  };
}