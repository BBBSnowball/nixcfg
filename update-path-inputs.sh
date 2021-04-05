#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq nixUnstable
set -e
if [ "$1" == "--help" -o $# -gt 1 ] ; then
  echo "Usage: $0 [hostname]" >&2
  exit 1
fi
hostname="$1"

NIX=(nix --experimental-features 'nix-command flakes')

if nix flake lock --help &>/dev/null ; then
  update_cmd=lock
elif nix flake update --help &>/dev/null ; then
  update_cmd=update
else
  update_cmd=
fi

if [ -n "$update_cmd" ] ; then
  echo "+ cd $PWD"
  jq <flake.lock '.nodes|to_entries|.[]|if .value.locked.type == "path" then .key else null end|select(.)' -r | xargs -n1 -t $NIX flake $update_cmd --update-input
  echo ""
  if [ -n "$hostname" -a -e "hosts/$hostname/flake.lock" ] ; then
    echo "+ cd $PWD/hosts/$hostname"
    ( cd "hosts/$hostname" && jq <flake.lock '.nodes|to_entries|.[]|if .value.locked.type == "path" then .key else null end|select(.)' -r | xargs -n1 -t $NIX flake $update_cmd --update-input )
    echo ""
  fi
else
  echo "WARN: Modern nix tooling not available -> not updating path:... in lock file." >&2
fi

