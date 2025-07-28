{ inputs, pkgs, config, ... }:
{
  programs.gpg = {
    enable = true;
    settings = {
      # Use GPG agent
      use-agent = true;

      # Security settings
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      charset = "utf-8";

      # Display settings
      fixed-list-mode = true;
      no-comments = true;
      no-emit-version = true;
      no-greeting = true;
      keyid-format = "0xlong";
      list-options = "show-uid-validity";
      verify-options = "show-uid-validity";
      with-fingerprint = true;

      # When outputting certificates, view user IDs distinctly from keys
      require-cross-certification = true;
      no-symkey-cache = true;
      throw-keyids = true;
    };
  };
}
