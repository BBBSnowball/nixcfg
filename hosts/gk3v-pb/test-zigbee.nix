{ lib, ... }:
{
  imports = [
    ../../homeautomation
  ];

  services.mosquitto = {
    enable = true;
    listeners = [ {
      address = "localhost";
      #omitPasswordAuth = true;
      users.guest.password = "guest";
      users.guest.acl = [ "readwrite #" ];
    } {
      address = "192.168.178.126";
      #omitPasswordAuth = true;
      users.guest.password = "guest";
      users.guest.acl = [ "readwrite #" ];
    } ];
  };

  # only start if network device is available
  systemd.services.mosquitto.wantedBy = lib.mkForce [ ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{INTERFACE}=="virbr0", TAG+="systemd", ENV{SYSTEMD_WANTS}="mosquitto.service"
  '';
}
