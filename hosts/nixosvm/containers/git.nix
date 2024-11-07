{ config, lib, modules, privateForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  mkForceMore = lib.mkOverride 40;
in {
  containers.git = {
    autoStart = true;
    config = { config, pkgs, ... }: let
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
      ];

      services.gitolite = {
        enable = true;
        user = "git";
        adminPubkey = builtins.readFile "${privateForHost}/../sonline0-shared/ssh-laptop.pub";
        enableGitAnnex = true;
      };

      services.openssh = {
        enable = true;
        ports = [ ports.gitolite.port ];
      };
      # openssh-with-unix-socket.nix changes the socket config -> force merged value
      systemd.sockets.sshd.socketConfig.ListenStream = mkForceMore [ ports.gitolite.port "/sshd.sock" ];
    };
  };

  networking.firewall.allowedPorts.gitolite = 8022;
}
