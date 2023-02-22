#! /usr/bin/env bash
set -e
if [ -z "$1" -o "$1" == "--help" ] ; then
  echo "Usage: $0 path/to/initrd/dir" >&2
  echo "e.g.   $0 ./result-initrd-test" >&2
  exit 1
fi
dir="$1"

args=(-m 8192)
args+=(-kernel "$dir"/bzImage -initrd "$dir"/initrd)
cmdline="boot.shell_on_fail"

if false ; then
  # ncurses interface. The downside is that we only get 80x25 chars and
  # this is often not enough to still see the start of error messages.
  args+=(-display curses)
else
  # console=ttyS0 breaks the kbd_mode command in the init script but that
  # doesn't seem to matter (except for a message being printed).
  cmdline+=" console=ttyS0"
  args+=(-nographic)
fi

sshport=$(nix eval --impure --expr '(import /etc/nixos/hosts/sonline0/private/data/by-host/sonline0/initrd.nix { testInQemu = true; }).port')
if ! [ "$sshport" -ge 1 -a "$sshport" -le 65535 ] ; then
  echo "Invalid SSH port! ($sshport)" >&2
  exit 1
fi
args+=(-nic user,model=e1000e,hostfwd=tcp::5555-:$sshport)

args+=(-append "$cmdline")

echo "Quit qemu with 'ctrl+a x' (or 'ctrl+a a x' under screen)"
echo "Connect with this command: ssh -p 5555 root@localhost"
set -x
exec qemu-kvm "${args[@]}"

# kexec --load --initrd ./initrd ./bzImage --reuse-cmdline
# kexec -fe

