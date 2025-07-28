{ pkgs }:

pkgs.rustPlatform.buildRustPackage rec {
  pname = "bip39";
  version = "1.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "robcohen";
    repo = "bip39-cli";
    rev = "fbbddacd6be5c864aee8c995adb448c5ca11f85e";
    sha256 = "11y6p2850v6v7z4v6dpfxvc9ybjwbkbv9vbbizixq1dc2p2vqq58";
  };

  cargoHash = "sha256-EoUJfgHljjHH9lwFQGvxqceIT/r9GzN+qkSeIHpBB6E=";

  nativeBuildInputs = with pkgs; [ pkg-config ];
  buildInputs = with pkgs; [ openssl ];

  meta = with pkgs.lib; {
    description = "BIP39 mnemonic CLI tool";
    homepage = "https://github.com/monomadic/bip39-cli";
    maintainers = [ ];
  };
}
