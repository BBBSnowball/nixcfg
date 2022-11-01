#!/usr/bin/env bash
set -xe
cd "$1"
chmod -R u+rw tmp
rm -f tmp/*.nix

cd tmp
tmp=$PWD
nix-build ../default.nix -A src -o src-link -I nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos
cp -LrT src-link src
chmod -R u+rw .

cd src/app
yarn2nix >$1/tmp/yarn-app.nix
cd ../server
yarn2nix >$1/tmp/yarn-server.nix

