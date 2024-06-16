{ lib, pkgs, config, disko, ... }:
let
  hostName = config.networking.hostName;

  pre = ''
    ls -1 /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_* | grep -v '[-]part\|_1$' | xargs -i{} ln -s {} /dev/alias-ssd1
    ls -1 /dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_* | grep -v '[-]part\|_1$' | xargs -i{} ln -s {} /dev/alias-ssd2
    modprobe dm-raid   # otherwise lvcreate will complain about raid1
    lvchange -a y ssd
  '';
  wrap = script: pkgs.writeShellScript script.name ''
    ${pre}
    exec ${script}
  '';
  wrapMount = script: pkgs.writeShellScript script.name ''
    ${pre}
    cryptsetup luksOpen /dev/ssd/root root
    exec ${script}
  '';
in
{
  config.system.build.disko = rec {
    lib = disko.lib;
    config = import ./partitions-disko.nix;
    packages = lib.packages config;

    createScript = wrap      (lib.formatScript config pkgs);
    mountScript  = wrapMount (lib.mountScript config pkgs);
    diskoScript  = wrap      (lib.diskoScript config pkgs);
  };
}
