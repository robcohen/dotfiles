{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: {

programs.git = {
      # Install git
      enable = true;
      
    # Additional options for the git program
    package = pkgs.gitAndTools.gitFull; # Install git wiith all the optional extras
    userName = "robcohen";
    userEmail = "3231868+robcohen@users.noreply.github.com";
#    signing.key = "";
#    signing.signByDefault = true;
    extraConfig = {
      core.editor = "\${EDITOR:-vim}";
      # Cache git credentials for 15 minutes
      credential.helper = "cache";
      # Sign all commits using ssh key (only if key exists)
      commit.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";
      # SSH signature verification
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      push = {
        autoSetupRemote = true;
      };
    };
  };

  # Create SSH allowed signers file for local verification
  home.file.".ssh/allowed_signers".text = ''
    3231868+robcohen@users.noreply.github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWh3QAAO6EVdxanzkoBbkDVfsxvNg+CioxnvKUfX6znOqD0rqlk4CE8DUStyOdkhMehl0ldQmatiIwBNu4+J4gTZfCHupmL2Y5lOb1oYEFmI6mionM6maKiBvdRvVq686S4RHsLTjKp3Y9ku0Py1vkNZYS+roON5fxlO67IZm5LoIG4JZ1ORcLPOJ9rTGmSgDzuQa44Y9CbcMLLarO37FNhxFKczWJyCx0+WLcezX6gLx5qP2saXCgJ6+l2eqtvDeKPLhUj5n5YaQO1YMGzJQimXmGvR1GZF0IjKO2r+GdugLUb+j0QqRoN18CO3F8UIN9MBDQPWkbiIj1MUR2sRdDH3EGKWIie4l2TrPuA24tI25VhVmZddiCcntBsH+pFOlY2ayEpegXBvbHi3NpRmVwX+wStnyl67OxSSi2b+Me/6E0RKZE+nMy7/SnmmyHWrtFBYu0mJ96aXwDXffqSwKfBMJgDeD8aVcF3teblp5KXOw+7XRgQmCH5DqitElfQsk=
  '';
}
