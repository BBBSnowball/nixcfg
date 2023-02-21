#! /usr/bin/env bash
set -ex
nix-build . --arg debugInQemu true
./result/bin/mkinitrd
echo "Quit qemu with 'ctrl+a x' (or 'ctrl+a a x' under screen)"
echo "Connect with this command: ssh -p 5555 root@localhost"
qemu-kvm -display curses \
  -m 1024 \
  -kernel result-initrd-test/bzImage -initrd result-initrd-test/initrd \
  -append "boot.shell_on_fail" \
  -nic user,model=e1000e,hostfwd=tcp::5555-:222 \
  -nographic -append "boot.shell_on_fail console=ttyS0"  # very useful but breaks kbd_mode in the init script

# kexec --load --initrd ./initrd ./bzImage --reuse-cmdline
# kexec -fe

