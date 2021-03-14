#!/bin/sh -e
if [ -z "$1" ] ; then
  echo "Usage: $0 hostname [nix-build opts]" >&2
  exit 1
fi
hostname="$1"
shift
#exec nix-build -E 'with builtins; with (getFlake (toString ./.)).nixosConfigurations; ('"$hostname"').config.system.build.toplevel' "$@"
exec nix --log-format bar-with-logs build .#nixosConfigurations."$hostname".config.system.build.toplevel "$@"
