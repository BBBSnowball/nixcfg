{ lib, pkgs, ... }:
let
  mountsForUser = user: {
    "/home/${user}/.local/share/docker" = {
      #device = "/home/${user}/data2/${user}-docker";
      device = "/home/${user}/data2/gos-docker";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };
  
    "/home/${user}/data2/${user}-data/nix/store" = {
      device = "/nix/store";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };

  };
in
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

  fileSystems = mountsForUser "gos"
    // mountsForUser "user3"
    #// mountsForUser "fxa"
    # -> not enough space for another volume, let's share them
    // {
      "/home/fxa/.local/share/docker" = {
        device = "/home/user3/data2/fxa-docker";
        fsType = "none";
        options = [ "bind" "nofail" ];
      };
    };

  environment.systemPackages = with pkgs; [
    btrfs-progs
  ];

  #systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "gos";  # default is "!root"
  systemd.user.services.docker.unitConfig.ConditionGroup = lib.mkForce "dockerrootless";
  users.groups.dockerrootless = {};

  # "android-udev-rules has been removed, as it is effectively superseded by built-in uaccess rules in systemd."
  #services.udev.packages = [ pkgs.android-udev-rules ];
  users.groups.adbusers = {};
  users.users.user.extraGroups = [ "adbusers" ];
  users.users.gos.extraGroups = [ "dockerrootless" ];

  # log limit is likely to hide important parts of the output for our builds so increase it
  # https://stackoverflow.com/questions/65819424/is-there-a-way-to-increase-the-log-size-in-docker-when-building-a-container/66230655#66230655
  # In theory, "-1" means unlimited but that is broken in some versions of BuildKit. In addition, some limit makes sense
  # just in case, we think. The default is 2 MB, which is good for 5% of the main build step.
  systemd.user.services.docker.environment = let
    MB = 1024*1024;
  in {
    BUILDKIT_STEP_LOG_MAX_SIZE = toString (1024 * MB);
    BUILDKIT_STEP_LOG_MAX_SPEED = toString (10 * MB);  # per second
  };
}
