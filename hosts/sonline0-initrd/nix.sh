# Usage:
# ./nix.sh flake check
# ./nix.sh run .
# ./nix.sh run .#make-sonline0-initrd-test
# ./nix.sh run .#test
if [ "$1" == "flake" ] ; then
  cmd=("$1" "$2")
  shift
  shift
else
  cmd=("$1")
  shift
fi
set -x
exec nix "${cmd[@]}" \
  --override-input routeromen ../.. \
  --override-input routeromen/private path:/etc/nixos/hosts/sonline0/private/data/ \
  "$@"
