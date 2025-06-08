{ pkgs }:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "bip39";
  version = "1.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "monomadic";
    repo = "bip39-cli";
    rev = "ee85cd6610fefaa6ba9b7b72ce2161c810cf6a48";
    sha256 = "sha256-F3wFh86Ri9nYXAN3p9WdzqpixTMutmzdWSAI/xsiKWE=";
  };

  cargoHash = "sha256-PBe8Jt8/YctCe22mLjexUyAbIIjKcWtulCcF/deeJ5I=";

  nativeBuildInputs = with pkgs; [ pkg-config ];
  buildInputs = with pkgs; [ openssl ];

  meta = with pkgs.lib; {
    description = "BIP39 mnemonic CLI tool";
    homepage = "https://github.com/monomadic/bip39-cli";
    maintainers = [ ];
  };
}