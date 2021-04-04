#!/bin/sh -e

set -e -o pipefail
shopt -s inherit_errexit

if [ -z "$1" -o -z "$2" -o "$1" == "--help" ] ; then
  echo "Usage: $0 hostname action [nix-build opts]" >&2
  echo "  action: test switch boot build dry-build dry-activate"
  echo "  actions not supported by nixos-rebuild: reboot build-drv diff-drv diff-cl/diff-closures"
  exit 1
fi
targetHost="$1"
action="$2"
shift; shift

cd "$(dirname "$0")"

./update-path-inputs.sh

targetHostCmd() {
    if [ -z "$targetHost" ]; then
        #"$@"
        eval "$*"
    else
        #FIXME I think ssh passes the command to the shell so we might want to use "$*". -> Indeed. Should we fix this in nixos-rebuild? Is it broken there or does it use different assumptions about the arguments of this function?
        #ssh $SSHOPTS "$targetHost" "$@"
        ssh $SSHOPTS "$targetHost" "$*"
    fi
}

post_cmd=
#extraBuildFlags=(-o "result-$targetHost")
extraBuildFlags=()
case "$action" in
  switch|boot)
    #extraBuildFlags=()
    ;;
  reboot)
    post_cmd="$action"
    action=boot
    #extraBuildFlags=()
    ;;
  build-drv)
    exec nix --experimental-features 'nix-command flakes' --log-format bar-with-logs \
      eval .#nixosConfigurations."$targetHost".config.system.build.toplevel.drvPath "$@"
    ;;
  diff-drv)
    currentDrv="$(targetHostCmd 'nix-store --query --deriver $(readlink -f /run/current-system)')"
    newDrv="$(nix --experimental-features 'nix-command flakes' --log-format bar-with-logs \
      eval --raw ".#nixosConfigurations.$targetHost.config.system.build.toplevel.drvPath" "$@")"
    if [ -e "$currentDrv" -o -z "$targetHost" ] ; then
      nix-shell -p nix-diff --run "nix-diff $currentDrv $newDrv"
    else
      nix-copy-closure --to "$targetHost" "$newDrv"
      targetHostCmd nix-shell -p nix-diff --run "\"nix-diff $currentDrv $newDrv\""
    fi
    ;;
  diff-cl|diff-closures)
    post_cmd="$action"
    action=build
    ;;
esac

# We have to pass `--flake` because nixos-rebuild would use the hostname of the current host.
# `nixos-rebuild` doesn't pass through `--log-format bar-with-logs` or `--print-build-logs` but `-L` works.
nixos-rebuild --target-host "$targetHost" --flake ".#$targetHost" "$action" -L "${extraBuildFlags[@]}" "$@"

case "$action" in
  switch|boot)
    ;;
  *)
    rm -f "./result-$targetHost"
    mv result "./result-$targetHost"
    ;;
esac

case "$post_cmd" in
  "")
    ;;
  reboot)
    targetHostCmd reboot
    ;;
  diff-cl|diff-closures)
    nix-copy-closure --to "$targetHost" "./result-$targetHost"
    targetHostCmd nix store diff-closures /run/current-system "$(readlink -f "result-$targetHost")"
    ;;
  *)
    echo "ERROR: unsupported post_cmd: $post_cmd" >&2
    exit 1
    ;;
esac

