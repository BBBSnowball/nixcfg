{ config, pkgs, lib, ... }:
{
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

      + Services
      menu = Services
      ++ DNS1
      probe = DNS
      host = bkoch.eu
      ++ DNS1b
      probe = DNS
      title = bkoch.eu @bkoch.eu
      host = bkoch.eu
      lookup = bkoch.eu
      ++ DNS2
      probe = DNS
      host = c3pb.de
      ++ DNS3
      probe = DNS
      host = hackerspace.servers.c3pb.de
      ++ DNS4
      host = google.de
    '';
  };
}
