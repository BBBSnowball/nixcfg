{ pkgs, ... }:
# I use this Zigbee coordinator:
# https://www.tindie.com/products/slaesh/cc2652-zigbee-coordinator-or-openthread-router/#
# https://www.zigbee2mqtt.io/information/supported_adapters.html#slaeshs-cc2652rb-stick
{
  options = {};
  config = {
    environment.systemPackages = with pkgs; [
      (pkgs.callPackage (import ./flash-cc2652-firmware.nix) {})
    ];
  };
}
