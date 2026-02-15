#! /bin/sh
# Usage: ./run.sh dryrun
# Usage: ./run.sh apply
# Usage: ./run.sh interactive-apply
set -xe
cd /etc/nixos/hosts/sonline0/private/private/by-host/sonline0/mailinabox
nix-build default.nix -o result-all
if [ "$1" != "" -a "$1" != "interactive-apply" ] ; then
  exec ./scripts/apply.sh "$@"
else
  shift
  ./scripts/apply.sh dryrun "$@"
  read -p "Apply changes? [y/N] " answer
  if [ "$answer" == "y" ] ; then
    ./scripts/apply.sh apply "$@"
  else
    echo "Aborted by user."
    exit 1
  fi
fi

