#!/bin/sh
# We use realpath on nixpkgs to avoid building a derivation that makes /etc/current-nixpkgs point to itself.
exec nix-build '<nixpkgs/nixos>' -A system "$@" -I nixpkgs="$(realpath "$(nix-instantiate --eval -E "<nixpkgs>")")"
