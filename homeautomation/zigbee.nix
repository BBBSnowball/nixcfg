{ config, pkgs, ... }:
# I use this Zigbee coordinator:
# https://www.tindie.com/products/slaesh/cc2652-zigbee-coordinator-or-openthread-router/#
# https://www.zigbee2mqtt.io/information/supported_adapters.html#slaeshs-cc2652rb-stick

# Listen to all messages: mosquitto_sub -t "zigbee2mqtt/#" -v

# Copy secret config after first start: cp /var/lib/zigbee2mqtt/secret.yaml /etc/nixos/private/secret/zigbee2mqtt.yaml
{
  options = {};

  imports = [
    (import <nixos-20.09/nixos/modules/services/misc/zigbee2mqtt.nix>)
  ];

  config = {
    nixpkgs.overlays = [
      (_: _: {
        zigbee2mqtt = (import <nixos-20.09> {}).zigbee2mqtt;
      })
    ];

    environment.systemPackages = with pkgs; [
      (pkgs.callPackage (import ./flash-cc2652-firmware.nix) {})
      mosquitto
    ];

    services.udev.extraRules = ''
      ATTRS{interface}=="slae.sh cc2652rb stick - slaesh's iot stuff", SYMLINK+="ttyZigbee", GROUP="zigbee2mqtt"
    '';

    services.zigbee2mqtt.enable = true;
    services.zigbee2mqtt.config = {
      serial.port = "/dev/ttyZigbee";
      mqtt.user = "!secret user";
      mqtt.password = "!secret password";
      advanced.network_key = "!secret network_key";
    };
    systemd.services.zigbee2mqtt.path = with pkgs; [ utillinux ];
    systemd.services.zigbee2mqtt.preStart = ''
      if [ -e /etc/nixos/private/secret/zigbee2mqtt.yaml ] ; then
        #ln -s /etc/nixos/private/secret/zigbee2mqtt.yaml ${config.services.zigbee2mqtt.dataDir}/secret.yaml
        install -m 400 -o zigbee2mqtt /etc/nixos/private/secret/zigbee2mqtt.yaml ${config.services.zigbee2mqtt.dataDir}/secret.yaml
      elif [ ! -e ${config.services.zigbee2mqtt.dataDir}/secret.yaml ] ; then
        umask 077
        (
          echo "user: guest"
          echo "password: guest"
          echo "network_key: [$(dd if=/dev/urandom bs=1 count=16 status=none|hexdump -e '15/1 "%d, " 1/1 " %d"')]"
        ) > ${config.services.zigbee2mqtt.dataDir}/secret.yaml
        chmod 400 ${config.services.zigbee2mqtt.dataDir}/secret.yaml
        chown zigbee2mqtt ${config.services.zigbee2mqtt.dataDir}/secret.yaml
      fi
    '';
    # only required while we manually import it from nixos-20.09
    ids.uids.zigbee2mqtt = 317;
    ids.gids.zigbee2mqtt = 317;
  };
}
