{ pkgs, lib, ... }:
let
  mosquitto_pub = "${pkgs.mosquitto}/bin/mosquitto_pub";
  actkbdConfig = pkgs.writeText "actkbd-g11.conf" ''
    691:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m M1
    692:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m M2
    693:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m M3
    688:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m MR
    656:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G1
    657:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G2
    658:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G3
    659:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G4
    660:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G5
    661:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G6
    662:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G7
    663:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G8
    664:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G9
    665:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G10
    666:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G11
    667:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G12
    668:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G13
    669:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G14
    670:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G15
    671:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G16
    672:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G17
    673:key::${mosquitto_pub} -h 10.0.2.1 -t component/g11/key -m G18
  '';

in
{
  environment.systemPackages = with pkgs; [
    actkbd
  ];

  services.udev.packages = lib.singleton (pkgs.writeTextFile {
    name = "actkbd-g11-udev-rules";
    destination = "/etc/udev/rules.d/91-actkbd-g11.rules";
    text = ''
      SUBSYSTEM=="input", KERNEL=="event[0-9]*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c225", ENV{ID_INPUT_KEY}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="actkbd-g11@%k.service"
    '';
  });

  systemd.services."actkbd-g11@" = {
    unitConfig = {
      Description = "actkbd for G11 Gaming Keys on %I";
      ConditionPathExists = "/dev/input/%I";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.actkbd}/bin/actkbd -c ${actkbdConfig} -d /dev/input/%I";
      User = "actkbd";
    };
  };

  users.users.actkbd = {
    isNormalUser = false;
    extraGroups = [ "input" ];
  };
}
