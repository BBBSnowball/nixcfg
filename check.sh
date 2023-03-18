#!/usr/bin/env bash
exec nix flake check --override-input private path:/etc/nixos/private-for-check/data/ "$@"
