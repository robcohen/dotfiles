{
  user = {
    name = "user";
    home = "/home/user";
    email = "robcohen@users.noreply.github.com";
    signingKey = "~/.ssh/id_ed25519.pub";
  };
  
  hosts = {
    brix = {
      swapPath = "/swapfile";
      swapSize = 32 * 1024;
    };
    slax = {
      swapPath = "/var/lib/swapfile";
      swapSize = 32 * 1024;
    };
    server-river = {
      swapPath = "/swapfile";
      swapSize = 16 * 1024;
    };
  };
}