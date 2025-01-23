#! /bin/sh
# Usage: ./run.sh dryrun
# Usage: ./run.sh apply
set -xe
cd /etc/nixos/hosts/sonline0/private/private/by-host/sonline0/mailinabox
nix-build dns-custom.nix -o result-dns
nix-build www-custom.nix -o result-www
nix-build mail.nix -o result-mail
exec ./scripts/apply.sh "$@"

