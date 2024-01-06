{ lib, config, pkgs, nixpkgs-unstable, secretForHost, ... }:
# I use this Zigbee coordinator:
# https://www.tindie.com/products/slaesh/cc2652-zigbee-coordinator-or-openthread-router/#
# https://www.zigbee2mqtt.io/information/supported_adapters.html#slaeshs-cc2652rb-stick

# Listen to all messages: mosquitto_sub -t "zigbee2mqtt/#" -v

# Copy secret config after first start: cp /var/lib/zigbee2mqtt/secret.yaml /etc/nixos/secret/by-host/routeromen/zigbee2mqtt.yaml
{
  options = {};

  imports = [
    # (import <nixos-20.09/nixos/modules/services/misc/zigbee2mqtt.nix>)
  ];

  config = {
    environment.systemPackages = with pkgs; [
      (pkgs.callPackage (import ./flash-cc2652-firmware.nix) {})
      (pkgs.callPackage (import ./flash-zbdongle-p-firmware.nix) {})
      mosquitto
      (pkgs.writeScriptBin "z2mctl" (builtins.readFile ./z2mctl.sh))
    ];

    services.udev.extraRules = ''
      ATTRS{interface}=="slae.sh cc2652rb stick - slaesh's iot stuff", SYMLINK+="ttyZigbee", GROUP="zigbee2mqtt", TAG+="systemd", ENV{SYSTEMD_WANTS}="zigbee2mqtt.service", ENV{SYSTEMD_ALIAS}="/sys/devices/ttyZigbee"
      ATTRS{interface}=="Sonoff Zigbee 3.0 USB Dongle Plus", SYMLINK+="ttyZigbee", GROUP="zigbee2mqtt", TAG+="systemd", ENV{SYSTEMD_WANTS}="zigbee2mqtt.service", ENV{SYSTEMD_ALIAS}="/sys/devices/ttyZigbee"
    '';
    systemd.services.zigbee2mqtt.bindsTo = [ "sys-devices-ttyZigbee.device" ];
    systemd.services.zigbee2mqtt.after   = [ "sys-devices-ttyZigbee.device" ];
    # don't start it by default because it would wait for the device
    systemd.services.zigbee2mqtt.wantedBy = lib.mkForce [ ];

    services.zigbee2mqtt.package = nixpkgs-unstable.legacyPackages.x86_64-linux.zigbee2mqtt;
    services.zigbee2mqtt.enable = true;
    services.zigbee2mqtt.settings = {
      serial.port = "/dev/ttyZigbee";
      mqtt.user = "!secret user";
      mqtt.password = "!secret password";
      advanced.network_key = "!secret network_key";
      advanced.pan_id = 6759;
      advanced.log_level = "warn";  # "info" logs every MQTT message - way too verbose
      #advanced.log_level = "info";  # but "warn" hides exceptions. oh, well...
      #advanced.log_level = "debug";
      advanced.log_output = [ "console" ];  # don't log to file, as well
      permit_join = false;

      frontend.port = 8086;  # default is 8080
      #FIXME This does *NOT* work. It is used as the auth token! -> disable auth, for now; port is behind firewall anyway
      #frontend.auth_token = "!secret auth_token";

      #homeassistant = true;
      homeassistant = {
        status_topic = "homeassistant/status";
      };
    };
    systemd.services.zigbee2mqtt.path = with pkgs; [ utillinux ];
    systemd.services.zigbee2mqtt.serviceConfig.SetCredential = [ "secret:none" ];  # provide default to make missing file for LoadCredential not fatal
    systemd.services.zigbee2mqtt.serviceConfig.LoadCredential = [ "secret:${secretForHost}/zigbee2mqtt.yaml" ];
    systemd.services.zigbee2mqtt.preStart = ''
      if [ -e $CREDENTIALS_DIRECTORY/secret ] && [ "$(cat $CREDENTIALS_DIRECTORY/secret)" != "none" ] ; then
        echo "Using secrets from $CREDENTIALS_DIRECTORY/secret"
        #install -m 400 -o zigbee2mqtt $CREDENTIALS_DIRECTORY/secret ${config.services.zigbee2mqtt.dataDir}/secret.yaml  # not allowed b/c of system call filters
        install -m 400 $CREDENTIALS_DIRECTORY/secret ${config.services.zigbee2mqtt.dataDir}/secret.yaml
      elif [ -e ${secretForHost}/zigbee2mqtt.yaml ] ; then
        echo "Using secrets from ${secretForHost}/zigbee2mqtt.yaml"
        #ln -s ${secretForHost}/zigbee2mqtt.yaml ${config.services.zigbee2mqtt.dataDir}/secret.yaml
        install -m 400 -o zigbee2mqtt ${secretForHost}/zigbee2mqtt.yaml ${config.services.zigbee2mqtt.dataDir}/secret.yaml
      elif [ ! -e ${config.services.zigbee2mqtt.dataDir}/secret.yaml ] ; then
        echo "Generating secrets at ${config.services.zigbee2mqtt.dataDir}/secret.yaml"
        umask 077
        (
          echo "user: guest"
          echo "password: guest"
          echo "network_key: [$(dd if=/dev/urandom bs=1 count=16 status=none|hexdump -e '15/1 "%d, " 1/1 " %d"')]"
          echo "auth_token: $(${pkgs.pwgen}/bin/pwgen -AB0 20 1)"
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
