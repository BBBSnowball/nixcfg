{ pkgs, ... }:
let
  #NOTE We probably don't need this because `systemctl kexec` might just work:
  #     https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/system/boot/kexec.nix
  #     -> not automatically but with: systemctl start prepare-kexec
  #     -> but it uses $profile/initrd, i.e. it won't work with secrets in the initrd
  # -> use our script

  kexecSystem = pkgs.writeShellScriptBin "kexec-system" ''
    set -e
    if [ -z "$1" ] ; then
      system=/nix/var/nix/profiles/system
    elif [ "$1" == "current" ] ; then
      system=/var/run/current-system
    elif [ "$1" == "booted" ] ; then
      system=/var/run/booted-system
    elif [ -d "$1/" ] ; then
      system="$1"
    elif [ -d "/nix/var/nix/profiles/system-$1-link/" ] ; then
      system="/nix/var/nix/profiles/system-$1-link/"
    else
      echo "I don't know how to get a system dir for that argument." >&2
      exit 1
    fi

    # see https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/system/boot/loader/systemd-boot/systemd-boot-builder.py
    kernel_params="init=$(realpath "$system/init") $(cat "$system/kernel-params")"
    initrd=$(umask 077; mktemp initrd-secrets.XXXXXXXXXX --tmpdir)
    "$system/append-initrd-secrets" "$initrd"
    ( set -x; kexec --load --initrd="$initrd" --append "$kernel_params" "$system/kernel" )
    rm "$initrd"
    echo 'Run `kexec --exec` (will not shutdown before) or `systemctl kexec` to start the new kernel.'
  '';
in
{
  environment.systemPackages = [ kexecSystem ];

  # This increases the chance of kexec working fine - or at least we will see the error message.
  boot.kernelParams = [ "nomodeset" ];
}
