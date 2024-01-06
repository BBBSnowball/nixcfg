{ lib, ... }:
{
  imports = [
    ./mqtt.nix
    ../../homeautomation/zigbee.nix
  ];

  #FIXME move to private
  services.zigbee2mqtt.settings.advanced.pan_id = lib.mkForce 6760;

  networking.firewall.allowedTCPPorts = [
    1883  # MQTT
    8086  # zigbee2mqtt
  ];
}
