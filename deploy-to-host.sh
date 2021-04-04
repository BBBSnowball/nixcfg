#!/bin/sh -e

#FIXME This is probably quite similar to `nixos-rebuild --target-host` -> can we use that?
#  -> I think this would ignore target-host for flakeAttr so we have to pass `--flake .#$hostname`.

set -e
if [ -z "$1" ] ; then
  echo "Usage: $0 hostname action [nix-build opts]" >&2
  echo "  action: test switch boot reboot build dry-build dry-activate"
  #FIXME add diff-derivation (copy derivation and call nix-diff with current system; or compare to old result-$hostname) and diff-closure (nix store diff-closure with current system on target host)
  exit 1
fi
hostname="$1"
shift

action="$1"
dry_build=0
deploy=1
set_profile=0
post_cmd=""
case "$1" in
  test|dry-activate)
    ;;
  switch|boot)
    set_profile=1
    ;;
  reboot)
    set_profile=1
    post_cmd=reboot
    ;;
  build)
    deploy=0
    ;;
  dry-build)
    dry_build=1
    deploy=0
    ;;
  *)
    echo "ERROR: invalid action: $1" >&2
    exit 1
    ;;
esac
shift

if [ $dry_build -gt 0 ] ; then
  pathToConfig="$(./build-for-host.sh "$hostname" "$@" --drv --raw)"
  if [ -e "$pathToConfig" ] ; then
    ln -sfT "$pathToConfig" "result-$hostname-drv"
  else
    echo "ERROR: result doesn't exist: $pathToConfig" >&2
    exit 1
  fi
else
  ./build-for-host.sh "$hostname" "$@" -o "result-$hostname"
  pathToConfig="$(realpath "./result-$hostname")"
fi

if [ $deploy -gt 0 ] ; then
  nix-copy-closure "$hostname" "$pathToConfig"
fi

if [ $set_profile -gt 0 ] ; then
  ssh "$hostname" nix-env -p "/nix/var/nix/profiles/system" --set "$pathToConfig"
fi

if [ -n "$action" ] ; then
  ssh "$hostname" "$pathToConfig/bin/switch-to-configuration" "$action"
fi

if [ -n "$post_cmd" ] ; then
  ssh "$hostname" $post_cmd
fi

