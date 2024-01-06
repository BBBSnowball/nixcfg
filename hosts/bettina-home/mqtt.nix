{ lib, ... }:
{
  services.mosquitto = {
    enable = true;
    listeners = let
      common = {
        users.guest.passwordFile = "/etc/nixos/secret/by-host/bettina-home/mqttpw";
        users.guest.acl = [ "readwrite #" ];
      };
    in [
      #(common // { address = "localhost"; })
      #(common // { address = "192.168.122.1"; })
      common
    ];
  };

  # only start if network device is available
  systemd.services.mosquitto.wantedBy = lib.mkForce [ ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{INTERFACE}=="virbr0", TAG+="systemd", ENV{SYSTEMD_WANTS}="mosquitto.service"
  '';
}
