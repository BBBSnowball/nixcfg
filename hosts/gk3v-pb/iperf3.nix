{ config, pkgs, lib, ... }:
{
  services.iperf3 = {
    enable = true;
    openFirewall = true;
  };

  # UDP test is selected by the client so we don't need a separate server for that
  # but we do have to open the port.
  networking.firewall.allowedUDPPorts = [
    config.services.iperf3.port
  ];

  # static build for mips (for running on old Omada APs):
  # ##with openssl, huge: nix-build -E '(import <nixpkgs> { crossSystem = { config = "mips-unknown-linux-gnu"; }; config.allowUnsupportedSystem = true; }).pkgsStatic.iperf3'
  # nix-build -E '((import <nixpkgs> { crossSystem = { config = "mips-unknown-linux-gnu"; }; config.allowUnsupportedSystem = true; }).pkgsStatic.iperf3.override { openssl = null; }).overrideAttrs (old: { configureFlags = []; })'
  # ssh user@ap 'cat >/tmp/logdump/iperf3' <result/bin/iperf3
  # ssh user@ ap 'cd /tmp/logdump && TEMP=. TMPDIR=. ./iperf3 -c target'  # tested on TP-Link EAP115
  # (server mode doesn't work unless we find an open port in the firewall)
}
