# `sudo -i` is broken on NixOS 20.09 because some systemd behavior
# has changed.
{ pkgs, ... }:
{
  environment.systemPackages = [ (pkgs.writeShellScriptBin "root" ''
    if [ -n "$1" ] ; then
      TUSER="$1"
    else
      TUSER="root"
    fi
    shell=$(getent passwd $TUSER 2>/dev/null | { IFS=: read _ _ _ _ _ _ x; echo "$x"; })
    exec machinectl shell --setenv=SHELL="$shell" "$TUSER@" "$shell" --login -i
  '') ];
}
