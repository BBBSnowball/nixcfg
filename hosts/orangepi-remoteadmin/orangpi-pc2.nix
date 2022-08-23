{ pkgs, ... }:
{
  system.build.u-boot = pkgs.buildUBoot {
    defconfig = "orangepi_pc2_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${pkgs.armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelParams = [
    "console=ttyS0,115200n8"
  ];
}
