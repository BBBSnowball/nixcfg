#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq nixUnstable
set -e
if [ "$1" == "--help" -o $# -gt 1 ] ; then
  echo "Usage: $0 [hostname]" >&2
  exit 1
fi
hostname="$1"

NIX=(nix --experimental-features 'nix-command flakes')

update_them() {
  # We used `nix flake lock --update-input private` but that tries to find the path in the flake, now.
  jq <flake.lock '.nodes|to_entries|.[]|if .value.locked.type == "path" then [.key, "path:" + .value.original.path] else null end|select(.)|.[]' -r | xargs -rn2 -t $NIX flake lock --override-input
}

echo "+ cd $PWD"
update_them
echo ""
if [ -n "$hostname" -a -e "hosts/$hostname/flake.lock" ] ; then
  echo "+ cd $PWD/hosts/$hostname"
  ( cd "hosts/$hostname" && update_them )
  echo ""
fi

