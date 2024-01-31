{ lib, pkgs, ... }:
{
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    daemon.settings = {
      storage-driver = "btrfs";

      # It seems to choose something that doesn't work...
      dns = [ "9.9.9.9" ];
    };
  };

  fileSystems."/home/gos/.local/share/docker" = {
    device = "/home/gos/data2/gos-docker";
    fsType = "none";
    options = [ "bind" ];
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
  ];

  systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "gos";  # default is "!root"
}
