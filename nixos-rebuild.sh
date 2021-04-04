#!/bin/sh -e

set -e
if [ -z "$1" -o -z "$2" -o "$1" == "--help" ] ; then
  echo "Usage: $0 hostname action [nix-build opts]" >&2
  echo "  action: test switch boot reboot build dry-build dry-activate"
  echo "  actions not supported by nixos-rebuild: reboot build-drv"
  #FIXME add diff-derivation (copy derivation and call nix-diff with current system; or compare to old result-$hostname) and diff-closure (nix store diff-closure with current system on target host)
  exit 1
fi
hostname="$1"
action="$2"
shift; shift

cd "$(dirname "$0")"

./update-path-inputs.sh

post_cmd=
case "$action" in
  reboot)
    action=boot
    post_cmd=reboot
    ;;
  build-drv)
    exec nix --experimental-features 'nix-command flakes' --log-format bar-with-logs \
      eval .#nixosConfigurations."$hostname".config.system.build.toplevel.drvPath "$@"
    ;;
esac

# We have to pass `--flake` because nixos-rebuild would use the hostname of the current host.
# `nixos-rebuild` doesn't pass through `--log-format bar-with-logs` or `--print-build-logs` but `-L` works.
nixos-rebuild --target-host "$hostname" --flake ".#$hostname" "$action" -L "$@"

if [ -n "$post_cmd" ] ; then
  ssh "$hostname" "$post_cmd"
fi

