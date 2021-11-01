{ config, pkgs, ... }:
let
  private    = "/etc/nixos/private/data";
  tincIP     = (builtins.head config.networking.interfaces."tinc.bbbsnowbal".ipv4.addresses).address;
in
{
  environment.systemPackages = [ pkgs.tinc ];

  services.tinc.networks.bbbsnowball = {
    name = builtins.replaceStrings ["-"] ["_"] config.networking.hostName;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true;
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=yes
      ConnectTo=sonline
      ConnectTo=routeromen
    '';
  };

  # mkdir /etc/nixos/private/data/tinc-pubkeys/bbbsnowball -p
  # nix-shell -p tinc --run "tincd -K 4096 -n bbbsnowball"
  #   /etc/nixos/secret/tinc-bbbsnowball-rsa_key.priv
  #   /etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname`
  # scp -3 gk3v:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname` omen-verl-remote:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname`
  # scp -3 gk3v:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/`hostname` nixos:/etc/nixos/private/tinc/pubkeys/bbbsnowball/`hostname`
  # scp -3 "root@nixos:/etc/nixos/private/tinc/pubkeys/bbbsnowball/*" root@`hostname`:/etc/nixos/private/data/tinc-pubkeys/bbbsnowball/

  systemd.services."tinc.bbbsnowball".preStart = ''
    ${pkgs.coreutils}/bin/install -o tinc.bbbsnowball -m755 -d /etc/tinc/bbbsnowball/hosts
    ${pkgs.coreutils}/bin/install -o root -m400 /etc/nixos/secret/tinc-bbbsnowball-rsa_key.priv /etc/tinc/bbbsnowball/rsa_key.priv

    #${pkgs.coreutils}/bin/install -o tinc.bbbsnowball -m444 ${private}/tinc-pubkeys/bbbsnowball/* /etc/tinc/bbbsnowball/hosts/
    ${pkgs.rsync}/bin/rsync -r --delete ${private}/tinc-pubkeys/bbbsnowball/ /etc/tinc/bbbsnowball/hosts
    chmod 444 /etc/tinc/bbbsnowball/hosts/*
    chown -R tinc.bbbsnowball /etc/tinc/bbbsnowball/hosts/
  '';
}
