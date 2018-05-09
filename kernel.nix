{ pkgs, ... }:
let
  rev = {
    "4.17-rc3.hdg.1" = "b8653b1e56ee1b5e8b3e11d7c17928dc7b9be3c8";
  };
  sha256 = {
    "4.17-rc3.hdg.1" = "137wldp9szs2w1zv5qxnlbzijgwal7iq47bfi4vzzwai7w0f8inm";

  };
  version =  "4.17-rc3.hdg.1";

  pkg = { stdenv, buildPackages, gnumake, hostPlatform, fetchurl, fetchFromGitHub, perl, buildLinux, libelf, utillinux, ... } @ args:
    buildLinux (args // rec {
      inherit version;
      kernelPatches = [
        pkgs.kernelPatches.bridge_stp_helper
        pkgs.kernelPatches.modinst_arg_list_too_long
      ];
      modDirVersion = "4.17.0-rc3";
      extrameta.branch = "4.17";
      src = fetchFromGitHub {
        owner = "jwrdegoede";
        repo = "linux-sunxi";
        rev = rev.${version};
        sha256 = sha256.${version};
      };
      extraConfig = ''
       ACPI_CUSTOM_METHOD m
       B43_SDIO y
       BATTERY_MAX17042 m

       COMMON_CLK y

       INTEL_SOC_PMIC? y
       INTEL_SOC_PMIC_CHTWC? y
       INTEL_PMC_IPC m
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
       RTC_DS1685_SYSFS_REGS y
       SERIAL_8250_DW y
       SERIAL_8250_MID y
       SERIAL_8250_NR_UARTS 32
       SERIAL_8250_PCI m
       SERIAL_DEV_BUS y
       SERIAL_DEV_CTRL_TTYPORT y
       TOUCHSCREEN_ELAN m
       TULIP_MMIO y
       W1_SLAVE_DS2433_CRC y
       XXHASH m
     '';
  });

in {
  nixpkgs.overlays = [ (self: super: {
    linux_gpd_pocket = super.callPackage pkg {};
  })];
}
