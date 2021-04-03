{ config, pkgs, ... }:
{
  services.openssh.enable = true;
  services.openssh.startWhenNeeded = true;
  services.openssh.openFirewall = false;
  services.openssh.listenAddresses = [{addr="127.0.0.1"; port=2201;}];  # dummy
  systemd.sockets.sshd.socketConfig.ListenStream = pkgs.lib.mkForce "/sshd.sock";
}
