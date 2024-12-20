{ lib, config, ... }:
let
  ourIp = "192.168.178.29";
  #iface = "enp0s13f0u4u4";
  iface = "enp0s13f0u3u4";

  moreSecure = config.environment.moreSecure;
in
{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    extraConfig = {
      # inspired by https://wiki.fogproject.org/wiki/index.php?title=ProxyDHCP_with_dnsmasq
      port = 0;
      log-dhcp = true;
      dhcp-no-override = true;
      dhcp-range = "${ourIp},proxy";

      enable-tftp = iface;
      tftp-root = "/tftpboot";
      tftp-port-range = "10000,10100";

      # U-Boot is sending a vendor class header but with type 60 instead of 43.
      # I think, dnsmasq doesn't consider this a valid request for proxy DHCP
      # because it doesn't answer.
      dhcp-boot = "default.kpxe,,${ourIp}";
      dhcp-vendorclass = "uboot,U-Boot";
      dhcp-boot = "net:uboot,bl808.kpxe,,${ourIp}";

      # This is supposed to show a menu but I don't think that this will work here.
      pxe-prompt = ''"Booting bl808 kernel", 1'';
      pxe-service = ''x86PC,"Boot bl808",bl808b.kpxe'';

      # be able to run in parallel with libvirt's dnsmasq
      #FIXME dnsmasq refuses to start because "unknown interface enp0s13f0u3u4" - but the interface exists. Well, that's a problem for later.
      interface = iface;
      bind-interfaces = true;
    };
  };

  networking.firewall = lib.mkIf (!moreSecure) {
    allowedUDPPorts = [ 67 69 ];
    allowedUDPPortRanges = [ { from = 10000; to = 10100; } ];
  };

  systemd.services.dnsmasq = {
    bindsTo = [ "sys-subsystem-net-devices-${iface}.device" ];
    after = [ "sys-subsystem-net-devices-${iface}.device" ];
    # don't start it by default because it would wait for the device
    wantedBy = lib.mkForce [ ];

    serviceConfig.RestartSec = 5;
  };

  # disabled for now because it conflicts with libvirt's dnsmasq and I do use the USB
  # ethernet device for other purposes, as well (i.e. this is not a good indicator of
  # whether we want to start the service or not)
  #
  #services.udev.extraRules = ''
  #  ACTION=="add", SUBSYSTEM=="net", ATTR{INTERFACE}=="${iface}", TAG+="systemd", ENV{SYSTEMD_WANTS}="dnsmasq.service"
  #'';
}
