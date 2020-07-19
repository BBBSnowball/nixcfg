{ config, pkgs, lib, ... }:
{
  nixpkgs.overlays = [ (import ./overlay.nix) ];
  environment.etc.abc.source = pkgs.edumeet-server;

  networking.firewall.allowedTCPPorts = [ 8030 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 40000; to = 40999; } ];

  services.redis = {
    enable = true;
    bind = "127.0.0.1";
    port = 0;
    unixSocket = "/run/redis/redis.sock";
    extraConfig = ''
      unixsocketperm 770
    '';
  };

  users.groups.redis-access = { };
  users.users.redis.group = "redis-access";
}
