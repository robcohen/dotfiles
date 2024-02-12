# Installation

## Update

`$ nix flake update`

`$ sudo nixos-rebuild switch --flake ~/Documents/dotfiles/#slax`

`$  home-manager switch --flake ~/Documents/dotfiles/#user@slax`

## Initial Install

```
$ sudo nixos-rebuild switch --flake .#slax
$ nix-shell '<home-manager>' -A install
$ home-manager switch --flake .#user@slax
```

ephemeral firefox:
```distrobox-ephemeral --image alpine:latest --additional-packages "firefox" -- firefox```
