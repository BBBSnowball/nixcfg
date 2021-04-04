#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq nixUnstable
set -e
if [ -z "$1" ] ; then
  echo "Usage: $0 hostname [nix-build opts]" >&2
  exit 1
fi
hostname="$1"
shift

cmd=build
extraPath=
if [ "$1" == "--drv" -o "$1" == "--derivation" ] ; then
  # see https://github.com/NixOS/nix/issues/3908
  shift
  cmd=eval
  extraPath=.drvPath
fi

NIX=(nix --experimental-features 'nix-command flakes')

if nix flake lock --help &>/dev/null ; then
  update_cmd=lock
elif nix flake update --help &>/dev/null ; then
  update_cmd=update
else
  update_cmd=
fi
if [ -n "$update_cmd" ] ; then
  jq <flake.lock '.nodes|to_entries|.[]|if .value.locked.type == "path" then .key else null end|select(.)' -r | xargs -n1 -t $NIX flake $update_cmd --update-input
  if [ -e "hosts/$hostname/flake.lock" ] ; then
    ( cd "hosts/$hostname" && jq <flake.lock '.nodes|to_entries|.[]|if .value.locked.type == "path" then .key else null end|select(.)' -r | xargs -n1 -t $NIX flake $update_cmd --update-input )
    fi
else
  echo "WARN: Modern nix tooling not available -> not updating path:... in lock file." >&2
fi

set -x
#exec nix-build -E 'with builtins; with (getFlake (toString ./.)).nixosConfigurations; ('"$hostname"').config.system.build.toplevel' "$@"
exec $NIX --log-format bar-with-logs $cmd .#nixosConfigurations."$hostname".config.system.build.toplevel$extraPath "$@"
