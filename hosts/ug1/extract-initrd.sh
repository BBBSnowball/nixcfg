#!/usr/bin/env bash
set -eo pipefail

initrd=/nix/var/nix/profiles/system/initrd
target=
while [ "$#" -gt 0 ] ; do
  case "$1" in
    --gen)
      initrd=/nix/var/nix/profiles/system-$2-link/initrd
      shift
      shift
      ;;
    --initrd)
      initrd="$2"
      shift
      shift
      ;;
    --to|--into)
      target="$2"
      shift
      shift
      ;;
    *)
      echo "Usage: $0 [--gen num] [--initrd file] [--to outputdir]" >&2
      exit 1
      ;;
  esac
done

if [ -z "$target" ] ; then
  target="$(umask 077; mktemp -td extract-initrd.XXXXXXXX)"
  echo "Extracting into $target ..."
else
  ( umask 077; mkdir -p "$target" )
fi

initrd="$(realpath "$initrd")"
cd "$target"
ln -s "$initrd" "file0"

i=0
while [ -e file$i ] ; do
  t="$(file --mime-type --brief -L file$i)"
  echo "file$i: $t"
  case "$t" in
    application/x-cpio)
      mkdir out$i
      cpio -idF file$i -D out$i --no-absolute-filenames
      if [ ! -e ./dracut ] ; then
        nix-build '<nixpkgs>' -A dracut -o dracut >/dev/null
      fi
      ./dracut/lib/dracut/skipcpio file$i >file$[$i+1]
      ;;
    application/zstd)
      zstd -d <file$i >file$[$i+1]
      ;;
    inode/x-empty)
      # done
      ;;
    *)
      echo "I don't know how to process this: $t" >&2
      exit 1
      ;;
  esac
  i=$[$i+1]
done

echo done.

