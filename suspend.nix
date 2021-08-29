let
  # see https://github.com/joshskidmore/gpd-pocket-arch-packages/blob/master/gpd-pocket-support/suspend-modules.sh
  # and suspend-*.conf in the same dir
  mods = "iwlwifi btusb goodix i2c_algo_bit i2c_cht_wc";
in
{
  # on resume the i2c bus complains, reloading the module helps
  powerManagement = {
    enable = true;
    powerDownCommands = ''
      modprobe -r ${mods}
    '';
    resumeCommands = ''
      modprobe ${mods}
    '';
  };
}
