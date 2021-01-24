#!/bin/sh
set -ex
nix build .#nixosConfigurations.routeromen.config.system.build.toplevel -o result-test-1
nixos-rebuild build && mv -Tf result result-test-2
nix-build '<nixpkgs/nixos>' -A system "$@" -I nixpkgs="$(realpath "$(nix-instantiate --eval -E "<nixpkgs>")")" -o result-test-3
for host in rockpro64-snowball ; do
  #nixos-rebuild build --flake .#$host -o result-test-$host-1
  #nix build --derivation .#nixosConfigurations.$host.config.system.build.toplevel -o result-test-$host-2
  nix-instantiate -E 'with builtins; with (getFlake (toString ./.)).nixosConfigurations; ('"$host"').config.system.build.toplevel' "$@" --add-root result-test-$host-3
  if [ -e hosts/$host/flake.nix ] ; then
    #nixos-rebuild build --flake ./hosts/$host#$host -o result-test-$host-4
    #nix build --derivation ./hosts/$host#nixosConfigurations.$host.config.system.build.toplevel -o result-test-$host-5
    nix-instantiate -E 'with builtins; with (getFlake (toString ./hosts/'"$host"')).nixosConfigurations; ('"$host"').config.system.build.toplevel' "$@" --add-root result-test-$host-6
  fi
done
