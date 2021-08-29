{ pkgs, lib, config, ... }:
{
  options.hardware.wifi-country-gpd-pocket = with lib; mkOption {
    type = types.nullOr types.str;
    default = null;
    description = ''
      Patch country code in brcmfmac4356-pcie.txt

      https://wiki.archlinux.org/title/GPD_Pocket#Wifi_not_seeing_channels_12/13/14
    '';
  };

  config.hardware.firmware = with pkgs; [
    firmwareLinuxNonfree
  ] ++ lib.optionals (config.hardware.wifi-country-gpd-pocket != null) [
    (pkgs.runCommand "gpd-pocket-wifi" {} ''
      mkdir -p $out/lib/firmware/brcm
      path=lib/firmware/brcm/brcmfmac4356-pcie.gpd-win-pocket.txt
      sed 's/^ccode=.*$/ccode=${config.hardware.wifi-country-gpd-pocket}/' <${firmwareLinuxNonfree}/$path >$out/$path
    '')
  ];
}
