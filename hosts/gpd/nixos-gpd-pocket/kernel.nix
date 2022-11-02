{ pkgs, ... }:
let
  linux_gpd_pocket_patches = {
    name = "gpd-pocket-config";
    patch = null;
    # Upstream has these as modules instead of builtin. We may have to add some of them to initrd.
    #  DW_DMAC_*, GPD_POCKET_FAN, HSU_DMA, NVRAM, RAW_DRIVER, SERIAL_8250_DW, SERIAL_8250_MID,
    #  INTEL_INT0002_VGPIO, INTEL_HID_EVENT, INTEL_VBTN, INTEL_PMC_CORE, INTEL_ATOMISP2_PM
    #NOTE This includes all config options that were set for the custom kernel. Not all of them are useful for GPD pocket but they shouldn't hurt either.
    extraConfig = ''
      #B43_SDIO y
      PMIC_OPREGION y
      XPOWER_PMIC_OPREGION y
      BXT_WC_PMIC_OPREGION y
      XPOWER_PMIC_OPREGION y
      CHT_DC_TI_PMIC_OPREGION y
      POWER_RESET y
      PWM y
      PWM_LPSS m
      PWM_LPSS_PCI m
      PWM_LPSS_PLATFORM m
      PWM_SYSFS y
      SERIAL_DEV_CTRL_TTYPORT y
      TULIP_MMIO y
      W1_SLAVE_DS2433_CRC y
      TYPEC_WCOVE m
      INTEL_SOC_PMIC y
      BXT_WC_PMIC_OPREGION y
      USB_LED_TRIG y
      MATOM y
      ACPI_APEI y
      ACPI_APEI_GHES y
      PCIEAER y
      ACPI_APEI_PCIEAER y
      CPU_FREQ_STAT y
      BT_HCIUART_INTEL y
      INTEL_SOC_PMIC y
      INTEL_SOC_PMIC_CHTWC y
      SND_SOC_INTEL_SKYLAKE_HDAUDIO_CODEC y
      #INTEL_PMC_IPC y
      INTEL_TURBO_MAX_3 y
      INTEL_IOMMU_SVM y
      EXTCON_INTEL_CHT_WC y
      INTEL_TXT y

      #FIXME We may want to keep this at the default because intel_pstate + performance governor might be a better choice than the name implies.
      # https://wiki.archlinux.org/title/CPU_frequency_scaling#Scaling_governors
      CPU_FREQ_STAT y
      CPU_FREQ_GOV_ONDEMAND y
      CPU_FREQ_DEFAULT_GOV_PERFORMANCE n
      #CPU_FREQ_DEFAULT_GOV_ONDEMAND y  # not available if Intel PSTATE is enabled
      CPU_FREQ_DEFAULT_GOV_SCHEDUTIL y

      MFD_INTEL_PMC_BXT y
      # required by other options, must not be a module
      I2C y
      I2C_DESIGNWARE_PLATFORM y
      SERIAL_DEV_BUS y

      #FIXME: error: unused option: INTEL_PMC_IPC
    '';
  };

  # list of modules for boot.initrd.kernelModules
  linux_gpd_pocket_modules = [
    "pwm-lpss" "pwm-lpss-platform" # for brightness control
    "g_serial" # be a serial device via OTG
    "gpd-pocket-fan" "hsu_dma" "8250_dw" "8250_mid" "intel_int0002_vgpio"
  ];
in {
  nixpkgs.overlays = [ (self: super: {
    inherit linux_gpd_pocket_patches linux_gpd_pocket_modules;
  })];
}
