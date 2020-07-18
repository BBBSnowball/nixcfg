{ config, pkgs, lib, ... }:
{
  nixpkgs.overlays = [ (import ./overlay.nix) ];
  environment.etc.abc.source = pkgs.edumeet-server;

  networking.firewall.allowedTCPPorts = [ 8030 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 40000; to = 40999; } ];

  services.redis = {
    enable = true;
    bind = "127.0.0.1";
    unixSocket = "/run/redis/redis.sock";
  };
}
