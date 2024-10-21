{ lib, pkgs, ... }:
{
  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
  };

  fileSystems."/var/lib/audiobookshelf" = {
    device = "/media/sdata/audiobookshelf";
    options = [ "bind,nofail,x-systemd.automount" ];
  };

  systemd.services.audiobookshelf = {
    after = [ "var-lib-audiobookshelf.automount" ];
    serviceConfig.StateDirectoryMode = "0700";
  };
}
