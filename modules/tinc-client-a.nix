{ config, pkgs, ... }:
let
  name       = "a";
  private    = "/etc/nixos/private/data";
  tincIP     = (builtins.head config.networking.interfaces."tinc.${name}".ipv4.addresses).address;
in
{
  environment.systemPackages = [ pkgs.tinc ];

  services.tinc.networks.${name} = {
    name = builtins.replaceStrings ["-"] ["_"] config.networking.hostName;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true;
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=yes
      ConnectTo=sonline
      #ConnectTo=routeromen

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

  systemd.services."tinc.${name}".preStart = ''
    ${pkgs.coreutils}/bin/install -o tinc.${name} -m755 -d /etc/tinc/${name}/hosts
    if [ -e "/etc/nixos/secret_local/tinc-${name}-rsa_key.priv" ] ; then
      ${pkgs.coreutils}/bin/install -o root -m400 /etc/nixos/secret_local/tinc-${name}-rsa_key.priv /etc/tinc/${name}/rsa_key.priv
    else
      ${pkgs.coreutils}/bin/install -o root -m400 /etc/nixos/secret/tinc-${name}-rsa_key.priv /etc/tinc/${name}/rsa_key.priv
    fi

    if [ -e "${private}/by-host/$HOSTNAME/tinc-pubkeys/${name}" ] ; then
      ${pkgs.rsync}/bin/rsync -r --delete "${private}/by-host/$HOSTNAME/tinc-pubkeys/${name}/" /etc/tinc/${name}/hosts
    else
      #${pkgs.coreutils}/bin/install -o tinc.${name} -m444 ${private}/tinc-pubkeys/${name}/* /etc/tinc/${name}/hosts/
      ${pkgs.rsync}/bin/rsync -r --delete ${private}/tinc-pubkeys/${name}/ /etc/tinc/${name}/hosts
    fi
    chmod 444 /etc/tinc/${name}/hosts/*
    chown -R tinc.${name} /etc/tinc/${name}/hosts/
  '';
}
