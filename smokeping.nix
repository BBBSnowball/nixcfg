{ config, pkgs, lib, ... }:
let
  nameserver = builtins.head config.networking.nameservers;
in
{
  nixpkgs.overlays = [
    (self: super: {
      smokeping = super.smokeping.overrideAttrs (old: {
        patches = (old.patches or []) ++ [./smokeping-drop-rsa1.patch];
      });
    })
  ];

  services.smokeping = {
    enable = true;
    imgUrl = "/cache";
    databaseConfig = ''
      step     = 300
      pings    = 20
      # consfn mrhb steps total
      AVERAGE  0.5   1  4032 # 5 min for 2 weeks
      AVERAGE  0.5  12  4320 # 1 hour for 180 days
          MIN  0.5  12  4320
          MAX  0.5  12  4320
      AVERAGE  0.5 144  7200 # 12 hours for 10 years
          MAX  0.5 144  7200
          MIN  0.5 144  7200
    '';
    probeConfig = ''
      + FPing
      binary = /run/wrappers/bin/fping
      ++ FPingNormal
      offset = 0%
      ++ FPing1k
      packetsize = 1000
      offset = 20%
      + DNS
      binary = ${pkgs.dnsutils}/bin/dig
      offset = 40%
      + SSH
      binary = ${pkgs.openssh}/bin/ssh-keyscan
      offset = 60%
    '';
    targetConfig = ''
      probe = FPingNormal
      menu = Top
      title = Network Latency Grapher
      + Hosts
      menu = Hosts
      title = Local Network and Internet
      ++ LocalMachine
      host = localhost
      ++ FritzBox
      title = FritzBox (192.168.178.1)
      host = 192.168.178.1
      ++ FritzBox1k
      probe = FPing1k
      title = FritzBox (192.168.178.1), 1k packets
      host = 192.168.178.1
      ++ Printer
      title = Printer (192.168.178.21)
      host = 192.168.178.21
      ++ work
      title = work (192.168.178.56)
      host = 192.168.178.56
      ++ work_1k
      probe = FPing1k
      title = work (192.168.178.56), 1k packets
      host = 192.168.178.56
      ++ Google
      host = google.de
      ++ DNS1
      title = DNS 1 (176.95.16.219)
      host = 176.95.16.219
      ++ DNS2
      title = DNS 2 (176.95.16.251)
      host = 176.95.16.251
      ++ mail_bkoch_info
      host = mail.bkoch.info
      ++ mail_bkoch_info_1k
      probe = FPing1k
      title = mail.bkoch.info, 1k packets
      host = mail.bkoch.info
      ++ c3pb_de
      host = c3pb.de
      ++ c3pb_de_1k
      probe = FPing1k
      title = c3pb.de, 1k packets
      host = c3pb.de
      ++ hackerspace
      host = hackerspace.servers.c3pb.de
      ++ verl
      host = verl.bbbsnowball.de
      ++ verl_1k
      probe = FPing1k
      title = verl.bbbsnowball.de, 1k packets
      host = verl.bbbsnowball.de
      ++ gpdpocket
      host = 192.168.178.68
      ++ gpdpocket_1k
      probe = FPing1k
      title = gpd pocket 192.168.178.68, 1k packets
      host = 192.168.178.68
      ++ laptop_lan
      host = 192.168.178.59
      ++ laptop_lan_1k
      probe = FPing1k
      title = laptop lan 192.168.178.59, 1k packets
      host = 192.168.178.59
      ++ laptop_wifi
      host = 192.168.178.67
      ++ laptop_wifi_1k
      probe = FPing1k
      title = laptop wifi 192.168.178.67, 1k packets
      host = 192.168.178.67
      ++ sslvpn4_beckhoff_com
      host = sslvpn4.beckhoff.com
      ++ sslvpn4_beckhoff_com_1k
      probe = FPing1k
      title = sslvpn4.beckhoff.com, 1k packets
      host = sslvpn4.beckhoff.com

      + Services
      menu = Services
      ++ DNS1
      probe = DNS
      menu  = dig bkoch.eu
      title = dig bkoch.eu
      lookup = bkoch.eu
      host = ${nameserver}
      ++ DNS1b
      probe = DNS
      menu  = dig bkoch.eu @bkoch.eu
      title = dig bkoch.eu @bkoch.eu
      host = bkoch.eu
      lookup = bkoch.eu
      ++ DNS2
      probe = DNS
      menu  = dig c3pb.de
      title = dig c3pb.de
      lookup = c3pb.de
      host = ${nameserver}
      ++ DNS3
      probe = DNS
      menu  = dig hackerspace.servers.c3pb.de
      title = dig hackerspace.servers.c3pb.de
      lookup = hackerspace.servers.c3pb.de
      host = ${nameserver}
      ++ DNS4
      probe = DNS
      menu  = dig google.de
      title = dig google.de
      lookup = google.de
      host = ${nameserver}
      ++ DNS5
      probe = DNS
      menu  = dig google.de @8.8.8.8
      title = dig google.de @8.8.8.8
      lookup = google.de
      host = 8.8.8.8
      ++ SSH1
      probe = SSH
      title = ssh-keyscan bkoch.eu
      host = bkoch.eu
      port = 22761
    '';
  };
}
