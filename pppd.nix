{ config, pkgs, ... }:
{
  systemd.network.networks.enp4s0.vlan = [ 7 8 ];
  networking.vlans.upstream-7 = {
    id = 7;
    interface = "enp4s0";
  };
  networking.vlans.upstream-8 = {
    id = 8;
    interface = "enp4s0";
  };

  environment.systemPackages = [ pkgs.ppp ];

  services.pppd = {
    enable = true;
    peers.upstream.config = "
      #debug
      logfile /dev/null
      noipdefault
      noaccomp
      nopcomp
      nocrtscts
      lock
      maxfail 0
      lcp-echo-failure 5
      lcp-echo-interval 1

      nodetach
      ipparam wan
      ifname pppoe-wan
      +ipv6
      #nodefaultroute
      defaultroute
      defaultroute6
      usepeerdns
      maxfail 1
      #ip-up-script /lib/netifd/ppp-up
      #ipv6-up-script /lib/netifd/ppp6-up
      #ip-down-script /lib/netifd/ppp-down
      #ipv6-down-script /lib/netifd/ppp-down
      mtu 1492
      mru 1492
      plugin rp-pppoe.so
      nic-upstream-7

      file /etc/nixos/secret/pppd-secret.conf
    ";
  };

  #services.shorewall.rules.pppoe = {
  #  # This won't work because we need to filter ethertype which is below IP layer.
  #  proto = "0x8863,0x8864,0x880b";
  #  rules = [
  #    { dest = "modem"; source = "$FW"; }
  #    { dest = "$FW";   source = "modem"; }
  #  ];
  #};

  systemd.services.pppd-upstream.serviceConfig.ReadWritePaths = [ "/etc/ppp" ];
}
