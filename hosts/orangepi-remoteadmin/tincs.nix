{ config, lib, pkgs, private, ... }:
let
  privateHostPath = "${private}/by-host/${config.networking.hostName}";
  privateHostValues = import privateHostPath;
  basename   = "a";
  # "main" connects via default gateway (e.g. usbnet or LAN) and it listens on all interfaces (e.g. Ethernet and/ or WiFi).
  # There are three ways to connect to it:
  # 1. Direct connection via WiFi or LAN. This works when the uplink is broken (which is important because the administered
  #    host omen-verl provides the uplink for that LAN).
  # 2. Through USB network, uplink, then sonline server. This will only work while omen-verl is alive and has uplink.
  # 3. Through GSM, then sonline server. This is the fallback and should work in all cases.
  #    (except when I'm on the same LAN and the uplink is broken - but then option 1 will work)
  parts      = [ "main" "modem" ];
  settings = rec {
    main.name = builtins.replaceStrings ["-"] ["_"] config.networking.hostName;
    modem.name = main.name + "_modem";
    main.LocalDiscovery = "yes";
    modem.LocalDiscovery = "no";
    main.port = 657;
    modem.port = 658;
    main.extraConfig = ''
      ConnectTo=${modem.name}
    '';
    modem.extraConfig = ''
      ConnectTo=${main.name}
    '';
    main.ip = privateHostValues.tinc-ip.a.main;
    modem.ip = privateHostValues.tinc-ip.a.modem;
  };
in
{
  config = lib.mkMerge (builtins.map (part: let
    name = "${basename}-${part}";
    partSettings = settings.${part};
    tincIP = partSettings.ip;
    pubkeys = pkgs.runCommand "tinc-pubkeys-${basename}" { base = "${privateHostPath}/tinc-pubkeys/${basename}"; } ''
      cp -r $base $out
    '';
  in {
    networking.firewall.allowedTCPPorts = [ settings.main.port ];

    services.tinc.networks.${name} = {
      name = partSettings.name;
      package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
      interfaceType = "tap";  # must be consistent across the network
      chroot = true;
      extraConfig = ''
        AddressFamily=ipv4
        Mode=switch
        LocalDiscovery=${partSettings.LocalDiscovery}
        ConnectTo=sonline
        ${partSettings.extraConfig}
  
        Port ${toString partSettings.port}

        # tincd chroots into /etc/tinc/${name} so we cannot put the file into /run, as we usually would.
        # Furthermore, tincd needs write access to the directory so we make a subdir.
        GraphDumpFile = status/graph.dot
      '';
    };

    systemd.services."tinc.${name}".preStart = ''
      netdir=/etc/tinc/${name}
      secretdir=/etc/nixos/secret
      secretKey=$secretdir/tinc-${name}-rsa_key.priv

      ${pkgs.coreutils}/bin/install -o tinc.${name} -m755 -d $netdir/hosts

      if [ -e $secretKey ] ; then
        ${pkgs.coreutils}/bin/install -o root -m400 $secretKey $netdir/rsa_key.priv
      elif [ -d $secretdir ] ; then
        ${config.services.tinc.networks.${name}.package}/bin/tincd -K 4096 -n ${name}
        ${pkgs.coreutils}/bin/install -o root -m400 $netdir/rsa_key.priv $secretKey
        echo "Address=127.0.0.1" >>$netdir/hosts/${partSettings.name}
        echo "Port=${toString partSettings.port}" >>$netdir/hosts/${partSettings.name}
        # make a backup so we don't delete it when restoring keys for private dir
        cp $netdir/hosts/${partSettings.name} $netdir/rsa_key.pub

        echo "Key has been generated. TODO: Copy $netdir/rsa_key.pub (with name ${partSettings.name}) to other hosts:"
        echo "- our private dir"
        echo "- to sonline (nixos:/etc/nixos/private/tinc/pubkeys/${basename}/${partSettings.name})"
        echo "- benny-laptop and fw (adding WiFi/LAN IP for main part)"
      else
        echo "ERROR no tinc key and no secrets dir" >&2
        exit 1
      fi
  
      #${pkgs.coreutils}/bin/install -o tinc.${name} -m444 ${pubkeys}/* $netdir/hosts/
      ${pkgs.rsync}/bin/rsync -r --delete ${pubkeys}/ $netdir/hosts
      chmod 444 $netdir/hosts/*
      chown -R tinc.${name} $netdir/hosts/

      ${pkgs.coreutils}/bin/install -o tinc.${name} -m755 -d /etc/tinc/${name}/status
    '';

    # NixOS network config doesn't setup the interface if we restart the tinc daemon
    # so let's set the IP address ourselves.
    environment.etc."tinc/${name}/tinc-up" = {
      text = ''
        #!/bin/sh
        ${pkgs.nettools}/bin/ifconfig $INTERFACE ${tincIP} netmask 255.255.255.0
      '';
      mode = "755";
    };
    environment.etc."tinc/${name}/tinc-down" = {
      text = ''
        #!/bin/sh
        ${pkgs.nettools}/bin/ifconfig $INTERFACE down
      '';
      mode = "755";
    };
    
    users.users."tinc.${name}".packages = [ pkgs.python3Packages.speedtest-cli pkgs.curl ];

    environment.systemPackages = let
      speedtestForUser = name: user: pkgs.writeShellScriptBin name ''
        su ${user} -s /bin/sh -c "exec speedtest-cli $*"
      '';
      ipForUser = name: user: pkgs.writeShellScriptBin name ''
        su ${user} -s /bin/sh -c "exec curl ifconfig.me"
      '';
    in [
      config.services.tinc.networks.${name}.package
      (speedtestForUser "speedtest-${part}" "tinc.${name}")
      (ipForUser "whatismyip-${part}" "tinc.${name}")
      (ipForUser "ip-${part}" "tinc.${name}")
    ];

  }) parts);
}
