# build with: nix-build . && ./result/bin/mkinitrd
# then: scp result-initrd/{bzImage,initrd} the-server:
#       ssh the-server kexec --load --initrd=initrd --reuse-cmdline bzImage
#       ssh the-server kexec --force --exec
{ debugInQemu ? false }:
let
  pkgs = import <nixpkgs> {};
  cfg = import <nixpkgs/nixos> {
    configuration = {
      imports = [ ./configuration.nix ];
      boot.initrd.debugInQemu = debugInQemu;
    };
  };
  inherit (cfg.config.system.build)
    kernel
    initialRamdisk
    initialRamdiskSecretAppender;
  dir = if cfg.config.boot.initrd.debugInQemu then "result-initrd-test" else "result-initrd";
in
(pkgs.writeShellScriptBin "mkinitrd" ''
  set -e
  umask 077
  dir=${dir}
  mkdir -p $dir
  rm -f $dir/{bzImage,initrd,initrd.tmp}
  cp -L ${kernel}/bzImage $dir/bzImage
  cp -L ${initialRamdisk}/initrd $dir/initrd.tmp
  chmod +w $dir/initrd.tmp
  ${initialRamdiskSecretAppender}/bin/append-initrd-secrets $dir/initrd.tmp
  mv $dir/initrd.tmp $dir/initrd
'') // {
  inherit
    kernel
    initialRamdisk
    initialRamdiskSecretAppender;
}
