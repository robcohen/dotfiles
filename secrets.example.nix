# Example secrets file - copy to secrets.nix and customize
# This file should never be committed to git!
{
  user = {
    name = "user";  # Your actual username
    email = "user@example.com";  # Your actual email
    realName = "User Name";  # Your real name for git
    githubUsername = "username";  # Your GitHub username  
    signingKey = "~/.ssh/id_ed25519.pub";  # Path to your SSH signing key
  };

  domains = {
    primary = "example.com";  # Your actual domain
    vpn = "vpn.example.com";  # VPN coordination server
    internal = "internal.example.com";  # Internal services domain
  };

  # Add other personal/sensitive configuration here
}