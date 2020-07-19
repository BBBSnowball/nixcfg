{ config, pkgs, lib, ... }:
let
  pkg = pkgs.edumeet-server;
in {
  nixpkgs.overlays = [ (import ./overlay.nix) ];

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

  users.users.edumeet = {
    description = "User for edumeet/multiparty-meeting server";
    isSystemUser = true;
    extraGroups = [ "redis-access" ];
  };

  systemd.services.edumeet = {
    description = "WebRTC meeting service (edumeet / multiparty-meeting)";

    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkg}/bin/edumeet-server";
      WorkingDirectory = "${pkg}/lib/edumeet-server";
      User = "edumeet";
    };
  };
}
