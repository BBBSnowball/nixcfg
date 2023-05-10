#!/bin/sh -e

set -e -o pipefail
shopt -s inherit_errexit

if [ $# -lt 2 -o "$1" == "--help" ] ; then
  echo "Usage: $0 hostname action [nix-build opts]" >&2
  echo "  action (like nixos-rebuild): test switch boot build dry-build dry-activate"
  echo "  more actions: reboot build-drv diff-drv diff-cl/diff-closures"
  echo "  set hostname to \"\" to build for the current host"
  exit 1
fi
targetHost="$1"
action="$2"
shift; shift

#cd "$(dirname "$(realpath "$0")")"
cd "$(dirname "$0")"

# doesn't work without an absolute path because bash would get ENOENT with a relative path. Why?!
# -> still doesn't work because the script would run in / instead of the current directory
#"$PWD/update-path-inputs.sh" "$targetHost"

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

# nixos-rebuild will resolve the symlink but only if we don't pass explicit --flake
# so we resolve it ourselves.
flake="$(dirname "$(realpath ./flake.nix)")"

if [ -z "$targetHost" ] ; then
  read -r hostname < /proc/sys/kernel/hostname
else
  hostname="$targetHost"
fi

echo "hostname: $hostname"

overrideInput=()
for x in \
  "./hosts/$hostname/private/private" \
  "./hosts/$hostname/private/data" \
  "./hosts/$hostname/private"
do
  if [ -d "$x/.git" ] ; then
    # We will only get here for a real .git directory. If this is a worktree with a .git file,
    # that's not great (hash may differ if we build this on more than one machine) but we don't
    # leak any sensitive or large information.
    # In any case, use a data subdir to avoid this.
    echo "Refusing to use this private dir because it contains a .git directory: $x" >&2
  elif [ -e "$x" ] ; then
    overrideInput=(--override-input private "path:$x")
    break
  fi
done

post_cmd=
#extraBuildFlags=(-o "result-$targetHost")
extraBuildFlags=()
needSshToTarget=0
case "$action" in
  test|dry-activate)
    needSshToTarget=1
    ;;
  switch|boot)
    #extraBuildFlags=()
    needSshToTarget=1
    ;;
  reboot)
    post_cmd="$action"
    action=boot
    #extraBuildFlags=()
    needSshToTarget=1
    ;;
  build-drv)
    exec nix --experimental-features 'nix-command flakes' --log-format bar-with-logs \
      eval ${overrideInput[@]} --raw "$flake#nixosConfigurations.$hostname.config.system.build.toplevel.drvPath" "$@"
    ;;
  diff-drv)
    currentDrv="$(targetHostCmd 'nix-store --query --deriver $(readlink -f /run/current-system)')"
    newDrv="$(nix --experimental-features 'nix-command flakes' --log-format bar-with-logs \
      eval ${overrideInput[@]} --raw "$flake#nixosConfigurations.$hostname.config.system.build.toplevel.drvPath" "$@")"
    if [ -e "$currentDrv" -o -z "$targetHost" ] ; then
      nix-shell -p nix-diff --run "nix-diff $currentDrv $newDrv"
    else
      nix-copy-closure --to "$targetHost" "$newDrv"
      targetHostCmd nix-shell -p nix-diff --run "\"nix-diff $currentDrv $newDrv\""
    fi
    exit
    ;;
  diff-cl|diff-closures)
    post_cmd="$action"
    action=build
    ;;
esac

if [ $needSshToTarget -ne 0 -a -n "$targetHost" ] ; then
  hosts=(--target-host "$targetHost" --build-host localhost)
  case "$hostname" in
    sonline0)
      hosts+=(--use-remote-sudo)
      ;;
  esac
else
  # don't set --target-host if we only want to build because nixos-rebuild would try to connect to it
  hosts=()
fi

case "$action" in
  switch|boot)
    generatesResult=0
    ;;
  test)
    if [ -n "$targetHost" ] ; then
      generatesResult=0
    else
      generatesResult=1
    fi
    ;;
  *)
    generatesResult=1
    ;;
esac
if [ $generatesResult -gt 0 ] ; then
  rm -f result
fi

# We have to pass `--flake` because nixos-rebuild would use the hostname of the current host.
# `nixos-rebuild` doesn't pass through `--log-format bar-with-logs` or `--print-build-logs` but `-L` works.
# Explicit build-host is required to work around a bug in nixos-rebuild: It would set buildHost=targetHost,
# build on the local host anyway, omit copying to target.
#NOTE If this fails because we don't have a nix with flake support (Nix 2.3), run it in a shell with nixFlakes
#     and set _NIXOS_REBUILD_REEXEC=1 so it doesn't force use of its internal version.
set -x
nixos-rebuild ${hosts[@]} --flake "$flake#$targetHost" "$action" -L ${overrideInput[@]} "${extraBuildFlags[@]}" "$@"
set +x

if [ $generatesResult -gt 0 ] ; then
    if [ -z "$targetHost" ] ; then
      read -r hostname < /proc/sys/kernel/hostname
      pathToConfig="./result-$hostname"
    else
      pathToConfig="./result-$targetHost"
    fi
    rm -f "$pathToConfig"
    mv result "$pathToConfig"
fi

case "$post_cmd" in
  "")
    ;;
  reboot)
    targetHostCmd reboot
    ;;
  diff-cl|diff-closures)
    if [ -n "$targetHost" ] ; then
      nix-copy-closure --to "$targetHost" "$pathToConfig"
    fi
    if targetHostCmd nix store --help &>/dev/null ; then
      targetHostCmd nix store diff-closures /run/current-system "$(readlink -f "$pathToConfig")"
    else
      targetHostCmd nix diff-closures /run/current-system "$(readlink -f "$pathToConfig")"
    fi
    ;;
  *)
    echo "ERROR: unsupported post_cmd: $post_cmd" >&2
    exit 1
    ;;
esac

