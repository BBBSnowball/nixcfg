{ pkgs, config, ... }:
let
  secretForHost = "/etc/nixos/secret/by-host/${config.networking.hostName}";
in
{
  networking.networkmanager.enable = true;

  systemd.services.NetworkManager.preStart = ''
    if [ -d ${secretForHost}/nm-system-connections ] ; then
      mkdir -p /etc/NetworkManager/system-connections/
      install -m 600 -t /etc/NetworkManager/system-connections/ ${secretForHost}/nm-system-connections/*
    fi
  '';

  environment.systemPackages = [ pkgs.iw ];
}
