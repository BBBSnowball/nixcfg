{ config, pkgs, lib, ... }:
{
  #services.geoip-updater.enable = true;  # doesn't work, NXDOMAIN
  services.ntopng.enable = true;
  services.ntopng.interfaces = [ "enp4s0" "enp2s0f0" "enp2s0f1" "enp2s0f2" "enp2s0f3" "wlp0s20f0u4" "nosuchinterface" ];

  services.redis.servers."".logLevel = "warning";
}
