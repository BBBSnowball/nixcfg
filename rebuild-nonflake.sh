#!/bin/sh
exec nix-build '<nixpkgs/nixos>' -A system "$@"
