#!/usr/bin/env bash
set -xe
cd "$(dirname "$0")"
mkdir -p tmp
chown test tmp
#systemd-run --uid test --pty --same-dir --wait --collect --service-type=exec
nixpkgs=$(nix eval --impure --expr 'with builtins; let x = getFlake (toString ../../..); in x.inputs.nixpkgs.outPath' --raw)
machinectl shell test@ \
  `which nix-shell` -p "yarn2nix" -I nixpkgs=$nixpkgs --run "$PWD/update2.sh $PWD"

cp tmp/yarn-{app,server}.nix .
