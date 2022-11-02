#!/bin/sh -xe

#what_to_build=config.system.build.nixos-rebuild
#what_to_build=config.nix.package.out
what_to_build=system

drv=`nix-instantiate  --expr "with import <nixpkgs/nixos> {}; $what_to_build"`
nix-copy-closure --to omen-verl-remote $drv
out=`ssh omen-verl-remote nix-build --no-out-link $drv`
nix-copy-closure --from omen-verl-remote --use-substitutes $out
ln -sfT $out result
