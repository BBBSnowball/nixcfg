{ lib, ... }:
let
in
{
  # enables usb-modeswitch, also useful for USB WiFi adapter that enumerates as CDROM, by default
  hardware.usbWwan.enable = true;

  # ModemManager needs polkit so keep it active although this is a headless system
  security.polkit.enable = lib.mkForce true;

  # ModemManager doesn't seem to start if we don't request it.
  systemd.services.ModemManager.wantedBy = [ "multi-user.target" ];

  # We want one tinc connection through wwan and the other one through the normal uplink so we have to apply some tricks.
  # - nmconnection file has ipv4.route-table=3 so the wwan route goes into a dedicated table.
  #   (use this to show them all: ip r show table all)
  # - add routing rules to change routing depending on fwmark
  #   ip rule add priority 1000 fwmark 3 table wwan
  #   ip rule add priority 100000 table wwan   # use wwan anyway if nothing else has matched so far
  # - set fwmark with iptables
  #   - One connection needs a different target port or something else that iptables can detect.
  #   - We could have several tinc daemons, each with a different user. They can have local connections
  #     to the main daemon so we don't care, which one of them forwards the packet.
  # http://linux-ip.net/html/routing-tables.html
  # http://linux-ip.net/html/routing-rpdb.html

  # won't work because we don't use networkd
  #systemd.network.config.routeTables = {
  #  wifi = 2;
  #  wwan = 3;
  #};
  networking.iproute2.enable = true;
  networking.iproute2.rttablesExtraConfig = ''
    2 wifi
    3 wwan
  '';
}
