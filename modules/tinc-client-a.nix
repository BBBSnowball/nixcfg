{ lib, config, pkgs, private, privateForHost, ... }:
let
  name       = "a";
  ifaceName  = builtins.substring 0 10 name;
  #tincIP     = (builtins.head config.networking.interfaces."tinc.${ifaceName}".ipv4.addresses).address;
  tincIPs    = map (x: "${x.address}/${toString x.prefixLength}") config.networking.interfaces."tinc.${ifaceName}".ipv4.addresses;
  hostName   = config.networking.hostName;
  ourName    = builtins.replaceStrings ["-"] ["_"] hostName;
in
{
  environment.systemPackages = [ pkgs.tinc ];

  services.tinc.networks.${name} = {
    name = ourName;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true;
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=yes
      ConnectTo=sonline
      #ConnectTo=routeromen

      # tincd chroots into /etc/tinc/${name} so we cannot put the file into /run, as we usually would.
      # Furthermore, tincd needs write access to the directory so we make a subdir.
      GraphDumpFile = status/graph.dot

      Port 657
    '';
  };

  # mkdir /etc/nixos/private/data/tinc-pubkeys/bbbsnowball -p
  # nix-shell -p tinc --run "tincd -K 4096 -n bbbsnowball"
  #   /etc/nixos/secret/tinc-bbbsnowball-rsa_key.priv
  #   /etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname`
  # scp -3 gk3v:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname` omen-verl-remote:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname`
  # scp -3 gk3v:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname` nixos:/etc/nixos/private/tinc/pubkeys/bbbsnowball/`hostname`
  # scp -3 "root@nixos:/etc/nixos/private/tinc/pubkeys/bbbsnowball/*" root@`hostname`:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/

  systemd.services."tinc.${name}" = {
    preStart = ''
      ${pkgs.coreutils}/bin/install -o tinc.${name} -m755 -d /etc/tinc/${name}/hosts
  
      if [ -e "/etc/nixos/secret_local/tinc-${name}-rsa_key.priv" ] ; then
        ${pkgs.coreutils}/bin/install -o root -m400 /etc/nixos/secret_local/tinc-${name}-rsa_key.priv /etc/tinc/${name}/rsa_key.priv
      else
        ${pkgs.coreutils}/bin/install -o root -m400 /etc/nixos/secret/tinc-${name}-rsa_key.priv /etc/tinc/${name}/rsa_key.priv
      fi
  
      if [ -e "${privateForHost}/tinc-pubkeys/${name}" ] ; then
        # We tell rsync to follow symlinks so the host-specific directory can refer to files in the common dir.
        ${pkgs.rsync}/bin/rsync -r --delete -L "${privateForHost}/tinc-pubkeys/${name}/" /etc/tinc/${name}/hosts
      else
        #${pkgs.coreutils}/bin/install -o tinc.${name} -m444 ${private}/tinc-pubkeys/${name}/* /etc/tinc/${name}/hosts/
        ${pkgs.rsync}/bin/rsync -r --delete ${private}/tinc-pubkeys/${name}/ /etc/tinc/${name}/hosts
      fi
  
      ${pkgs.coreutils}/bin/install -d -o tinc.${name} -m700 /etc/tinc/${name}/status
  
      chmod 444 /etc/tinc/${name}/hosts/*
      chown -R tinc.${name} /etc/tinc/${name}/hosts/
    '';

    serviceConfig.BindPaths = [
      "/etc/resolv.conf:/etc/tinc/${name}/etc/resolv.conf"
    ];
  };

  # NixOS network config doesn't setup the interface if we restart the tinc daemon
  # so let's add some redundancy:
  environment.etc = lib.mkIf (builtins.length tincIPs > 0) {
    "tinc/${name}/tinc-up" = {
      text = ''
        #!/bin/sh
        #''${pkgs.nettools}/bin/ifconfig $INTERFACE ''${tinc-a-address} netmask 255.255.255.0
        ${pkgs.iproute2}/bin/ip link set $INTERFACE up
        for addr in ${toString tincIPs} ; do
          ${pkgs.iproute2}/bin/ip address add $addr dev $INTERFACE
        done
      '';
      mode = "755";
    };
    "tinc/${name}/tinc-down" = {
      text = ''
        #!/bin/sh
        ''${pkgs.nettools}/bin/ifconfig $INTERFACE down
        ${pkgs.iproute2}/bin/ip link set $INTERFACE down
      '';
      mode = "755";
    };
  };
}
