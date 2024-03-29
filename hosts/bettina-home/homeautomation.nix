{ lib, pkgs, ... }:
{
  imports = [
    ./mqtt.nix
    ../../homeautomation/zigbee.nix
  ];

  #FIXME move to private
  services.zigbee2mqtt.settings.advanced.pan_id = lib.mkForce 6760;

  services.zigbee2mqtt.settings.frontend.auth_token = "!secret auth_token";

  # don't bother to start it if the mqtt server has failed for some reason
  systemd.services.zigbee2mqtt.requires = [ "mosquitto.service" ];

  networking.firewall.allowedTCPPorts = [
    1883  # MQTT
    8086  # zigbee2mqtt
    8123  # HomeAssistant
  ];

  systemd.services.fwd-ha = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:8123,fork TCP6-CONNECT:[fe80::3a3a:2ea1:5b27:2037%%br0]:8123";
    };
  };
}
