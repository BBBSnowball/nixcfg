{ config, pkgs, lib, ... }:
let
  nameserver = config.services.smokeping.nameserver;
  fping = { name = ""; probe = null; key = ""; };
  fping1k = { name = ", 1k packets"; probe = "FPing1k"; key = "1k"; };
  fping_1k = fping1k // { key = "_1k"; };  # just different key to keep it as before
  targetHosts = [
    #{ host = "localhost"; key = "LocalMachine"; }
    { name = "FritzBox"; host = "192.168.178.1"; probes = [ fping fping1k ]; }
    { name = "Printer"; host = "192.168.178.21"; }
    { name = "work"; host = "192.168.178.56"; probes = [ fping fping_1k ]; }
    { name = "192.168.178.30"; host = "192.168.178.30"; probes = [ fping fping_1k ]; }
    { name = "192.168.178.33"; host = "192.168.178.33"; probes = [ fping fping_1k ]; }
    { key = "Google"; host = "google.de"; }
    #rec { key = "DNS1"; name = "DNS 1 (${host})"; host = "176.95.16.219"; }
    { name = "DNS 1"; host = "176.95.16.219"; }
    { name = "DNS 2"; host = "176.95.16.251"; }
    { host = "mail.bkoch.info"; probes = [ fping fping_1k ]; }
    { host = "ping.online.net"; probes = [ fping fping_1k ]; }
    { host = "c3pb.de"; probes = [ fping fping_1k ]; }
    { host = "94.79.177.225"; name = "hackerspace-fritzbox"; }  # IP of hackerspace minus 1
    { host = "hackerspace.servers.c3pb.de"; name = "hackerspace"; }
    { host = "verl.bbbsnowball.de"; name = "verl"; probes = [ fping fping_1k ]; }
    { name = "gpd pocket"; host = "192.168.178.68"; probes = [ fping fping_1k ]; }
    { name = "laptop lan"; key = "laptop_lan"; host = "192.168.178.59"; probes = [ fping fping_1k ]; }
    { name = "laptop wifi"; key = "laptop_wifi"; host = "192.168.178.67"; probes = [ fping fping_1k ]; }
    { host = "sslvpn4.beckhoff.com"; probes = [ fping fping_1k ]; }
    { host = "sslvpn2.beckhoff.com"; probes = [ fping fping_1k ]; }

    # Telekom (DTAG) is dropping *lots* of packets from France, even from large
    # Tier 1 providers. Let's collect some stats about that.

    # https://www.cogentco.com/en/looking-glass
    { name = "Cogent, Paris";     host = "ism01.par01.atlas.cogentco.com"; }
    { name = "Cogent, Marseille"; host = "ism01.mrs01.atlas.cogentco.com"; }
    { name = "Cogent, Bordeaux";  host = "ism01.bod01.atlas.cogentco.com"; }
    { name = "Cogent, Berlin";    host = "ism01.ber01.atlas.cogentco.com"; }
    { name = "Cogent, London";    host = "ism01.lon13.atlas.cogentco.com"; }

    # Level 3 / CenturyLink
    # https://lookingglass.centurylink.com/
    #{ name = "Level 3, Paris";     host = "lo-22.ear1.Paris1.Level3.net"; }
    #{ name = "Level 3, Marseille"; host = "lo0.0.edge4.Marseille1.level3.net"; }
    #{ name = "Level 3, London";    host = "lo-0.ear1.London1.Level3.net"; }

    # Telia
    # https://lg.twelve99.net/?type=ping&router=prs-b8&address=163.172.39.101
    { name = "Telia, Paris 1"; host = "prs-b6.ip.twelve99.net"; }
    { name = "Telia, Paris 2"; host = "prs-b8.ip.twelve99.net"; }
    { name = "Telia, Paris 3"; host = "prs-b8.ip.twelve99.net"; }
    #{ name = "Telia, London";  host = "slou-b1.ip.twelve99.net"; }
  ];
  completeHost = x: rec {
    key    = x.key or (lib.strings.replaceStrings ["." "," " "] ["_" "_" ""] name);
    host   = x.host;
    name   = x.name or x.host;
    title  = x.title or (if host == name then name else "${name} (${host})");
    probes = x.probes or [ fping ];
  };
  perProbe = x: probe: x // {
    key = x.key + probe.key;
    name = x.name + probe.name;
    title = x.title + probe.name;
    probe = probe.probe;
  };
  targetHostsPerProbe = lib.concatMap (x: let y = completeHost x; in map (perProbe y) y.probes) targetHosts;
  renderProbe = with lib; p: replaceStrings ["\n\n\n" "\n\n"] ["\n" "\n"] ''
    ++ ${p.key}
    ${optionalString (p.probe != null) "probe = ${p.probe}"}
    ${optionalString (p.title != p.host) "title = ${p.title}\nmenu = ${p.title}"}
    host = ${p.host}
  '';
  targetHostsText = lib.concatMapStringsSep "" renderProbe targetHostsPerProbe;
  # compare to previous: nixos-rebuild build && ( x="$(sed -En 's/^ExecStart=([^ ]*)( .*)?/\1/p' result/etc/systemd/system/smokeping.service)"; y="$(sed -En 's/.*--config=([^ ]*) .*/\1/p' "$x")"; diff /nix/store/mck2kz613hcs8d35mf0p0bm9pg8jpd2q-smokeping.conf "$y" -u )

in
{
  options.services.smokeping.nameserver = with lib; mkOption {
    type = types.str;
    description = "Nameserver to use for most DNS probes";
    # e.g. builtins.head config.networking.nameservers;
    default = "127.0.0.53";  # systemd-resolved
  };

  config.nixpkgs.overlays = [
    (import ../../pkgs/smokepingOverlay.nix)
  ];

  config.services.smokeping = {
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

      + speedtest
      binary = ${pkgs.speedtest-cli}/bin/speedtest-cli
      timeout = 300
      forks = 1
      step = 3600
      offset = random
      pings = 3
      ++ speedtest-download
      measurement = download
      ++ speedtest-upload
      measurement = upload
    '';
    targetConfig = ''
      probe = FPingNormal
      menu = Top
      title = Network Latency Grapher
      + Hosts
      menu = Hosts
      title = Local Network and Internet
      ${targetHostsText}
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
      host = c3pb.de
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

      + Speedtest
      menu = Speedtest
      title = Speedtest
      ++ from_closest
      title = from closest
      menu = from closest
      probe = speedtest-download
      host = dummy.com
      ++ to_closest
      title = to closest
      menu = to closest
      probe = speedtest-upload
      host = dummy.com
      #NOTE We cannot use any servers that aren't offered to us. Meh.
      #++ from_frace1
      #title = from France
      #menu = from France
      #probe = speedtest-download
      #server = 39765
      #host = dummy.com
      #++ to_france1
      #title = to France
      #menu = to France
      #probe = speedtest-upload
      #server = 39765
      #host = dummy.com
    '';
  };

  #config.systemd.services.smokeping.serviceConfig.ExecStartPost = "!${pkgs.systemd}/bin/systemctl start thttpd";
  config.systemd.services.smokeping.wants = [ "thttpd.service" ];
}
