{ pkgs, ... }:
{
  networking.networkmanager.enable = true;

  systemd.services.NetworkManager.preStart = ''
    if [ -d /etc/nixos/secret/nm-system-connections ] ; then
      mkdir -p /etc/NetworkManager/system-connections/
      install -m 600 -t /etc/NetworkManager/system-connections/ /etc/nixos/secret/nm-system-connections/*
    fi
  '';

  environment.systemPackages = [ pkgs.iw ];
}
