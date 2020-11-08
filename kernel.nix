{ pkgs, ... }:
let
  rev = {
    "4.17-rc3.hdg.1" = "b8653b1e56ee1b5e8b3e11d7c17928dc7b9be3c8";
    "5.8" = "842bb80b0ed5e8f34d9c9bd403e4b510acfe7514";
  };
  sha256 = {
    "4.17-rc3.hdg.1" = "137wldp9szs2w1zv5qxnlbzijgwal7iq47bfi4vzzwai7w0f8inm";
    "5.8" = "0l6yawcn6slqj4kzarz1w2yj9wfa0p068ilfzmlfhfyylgk094m1";
  };
  #version =  "4.17-rc3.hdg.1";
  version =  "5.8";

  cleanSource = src: pkgs.runCommand "clean-src-${version}" {} ''
    set -ex
    cp -r ${src} $out
    chmod u+rw -R $out
    rm $out/.config
    ${pkgs.gnumake}/bin/make -C $out mrproper
  '';

  pkg = { stdenv, buildPackages, gnumake, hostPlatform, fetchurl, fetchFromGitHub, perl, buildLinux, libelf, utillinux, flex, bison, ... } @ args:
    buildLinux (args // rec {
      inherit version;
      kernelPatches = [
        pkgs.kernelPatches.bridge_stp_helper
        #pkgs.kernelPatches.modinst_arg_list_too_long
      ];
      modDirVersion = "5.8.0";
      extrameta.branch = "5.8-footrail";
      src = cleanSource (fetchFromGitHub {
        owner = "jwrdegoede";
        repo = "linux-sunxi";
        rev = rev.${version};
        sha256 = sha256.${version};
      });
      nativeBuildInputs = [ flex bison ];
      extraConfig = ''
       ACPI_CUSTOM_METHOD m
       B43_SDIO y
       BATTERY_MAX17042 m

       COMMON_CLK y

       INTEL_SOC_PMIC? y
       INTEL_SOC_PMIC_CHTWC? y
       #FIXME: INTEL_PMC_IPC m
       INTEL_BXTWC_PMIC_TMU m

       ACPI y
       PMIC_OPREGION y
       CHT_WC_PMIC_OPREGION? y
       XPOWER_PMIC_OPREGION y
       BXT_WC_PMIC_OPREGION y
       CRC_PMIC_OPREGION? y # wtf. nix kernel config script is madness
       XPOWER_PMIC_OPREGION y
       CHT_DC_TI_PMIC_OPREGION y

       #EXTCON_INTEL_CHT_WC? y # wtf

       DW_DMAC y
       DW_DMAC_CORE y
       DW_DMAC_PCI y
       GPD_POCKET_FAN y
       HSU_DMA y
       I2C_CHT_WC? y
       I2C_DESIGNWARE_BAYTRAIL? y
       INTEL_CHT_INT33FE m
       MFD_AXP20X m
       #MUX_INTEL_CHT_USB_MUX m
       TYPEC_MUX_PI3USB30532 m
       #MUX_PI3USB30532 m
       NVRAM y
       POWER_RESET y
       PWM y
       PWM_LPSS m
       PWM_LPSS_PCI m
       PWM_LPSS_PLATFORM m
       PWM_SYSFS y
       RAW_DRIVER y
       #FIXME: RTC_DS1685_SYSFS_REGS y
       SERIAL_8250_DW y
       SERIAL_8250_MID y
       SERIAL_8250_NR_UARTS 32
       SERIAL_8250_PCI m
       SERIAL_DEV_BUS y
       SERIAL_DEV_CTRL_TTYPORT y
       TOUCHSCREEN_ELAN m
       TULIP_MMIO y
       W1_SLAVE_DS2433_CRC y
       XXHASH y
     '';
  });

in {
  nixpkgs.overlays = [ (self: super: {
    linux_gpd_pocket = super.callPackage pkg {};
  })];
}
