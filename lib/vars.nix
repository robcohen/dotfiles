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
    server-river = {
      swapPath = "/swapfile";
      swapSize = 16 * 1024;
      homeManagerStateVersion = "23.11";
      type = "server";
      features = [ "headless" "backup" ];
    };
  };
}