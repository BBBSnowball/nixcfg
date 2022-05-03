{ config, pkgs, ... }:
let
  ipUpScript = pkgs.writeShellScript "pppd-ip-up" ''
    # args are: interface-name tty-device speed local-IP-address remote-IP-address ipparam
    export PATH=${with pkgs; lib.makeBinPath [ coreutils procps systemd inetutils ]}
    logger "pppd-ip-up: reload shorewall"
    systemctl reload shorewall.service
    sleep 10
    logger "pppd-ip-up: trigger ddclient"
    systemctl start ddclient.service
  '';
  ipv6UpScript = pkgs.writeShellScript "pppd-ipv6-up" ''
    # Telekom sends Router Advertisements to tell us about our IPv6 address
    # so we better accept them although we are a router (therefore, 2 instead of 1).
    export PATH=${with pkgs; lib.makeBinPath [ coreutils procps systemd inetutils ]}
    logger "pppd-ipv6-up: set accept_ra=2"
    sysctl -w net.ipv6.conf.$PPP_IFACE.accept_ra=2
    sysctl -w net.ipv6.conf.$IFNAME.accept_ra=2
  '';
in
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
      ip-up-script ${ipUpScript}
      #ipv6-up-script ${ipv6UpScript}
      #ip-down-script /lib/netifd/ppp-down
      #ipv6-down-script /lib/netifd/ppp-down
      mtu 1492
      mru 1492
      plugin rp-pppoe.so
      # name of the network interface. pppd sometimes claims that this is an invalid
      # option. I assume because the interface doesn't exist at that time.
      nic-upstream-7

      file /etc/nixos/secret/pppd-secret.conf
    ";
  };

  environment.etc."ppp/ip-up".source = ipUpScript;
  #environment.etc."ppp/ipv6-up".source = ipv6UpScript;

  services.udev.packages =  [
    (pkgs.writeTextFile rec {
      name = "accept_ra_for_pppoe.rules";
      destination = "/etc/udev/rules.d/99-${name}";
      # test with: nixos-rebuild test && udevadm control --log-priority=debug && udevadm trigger /sys/devices/virtual/net/pppoe-wan --action=add
      text = ''
        #
        ACTION=="add|change|move", SUBSYSTEM=="net", ENV{INTERFACE}=="pppoe-wan", RUN+="${pkgs.procps}/bin/sysctl net.ipv6.conf.pppoe-wan.accept_ra=2"
      '';
    })
  ];

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
