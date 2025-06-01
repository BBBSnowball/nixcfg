#! /bin/sh
# Usage: ./run.sh dryrun
# Usage: ./run.sh apply
set -xe
cd /etc/nixos/hosts/sonline0/private/private/by-host/sonline0/mailinabox
nix-build default.nix -o result-all
exec ./scripts/apply.sh "$@"

