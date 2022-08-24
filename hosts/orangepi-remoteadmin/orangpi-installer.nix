# Usage: nix build ".#nixosConfigurations.$machine.config.system.build.orangepi-installer" && ./result/install --wipe-this-disk /dev/thesdcard
#
# If you use the `private` input of the routeromen flake, add this to the `nix build`:
#   --override-input routeromen/private path:/etc/nixos/hosts/orangepi-remoteadmin/private/data

{ lib, pkgs, config, ... }:
with import ./uuid.nix { inherit lib; };
with builtins;
with lib;
let
  uuidBaseType = with types; submodule {
    options = {
      bytes = mkOption { type = listOf int; };
      outPath = mkOption { type = str; };
      version = mkOption { type = int; };
      variant = mkOption { type = int; };
    };
  };
  uuidType = lib.types.coercedTo types.str toUUID uuidBaseType;
in
{
  options = with types; {
    system.baseUUID = mkOption {
      description = ''
        Base UUID for generating the other UUIDs. This can be the nil UUID
        if all hostnames are unique. As someone else might use the same hostname,
        we suggest to generate a random UUID with uuidgen.
      '';
      type = uuidType;
      defaultText = toString nilUUID;
      default = nilUUID;
    };
    system.systemUUID = mkOption {
      description = ''
        System UUID for generating unique values for this system.
      '';
      type = uuidType;
      defaultText = "namespacedUUIDNonStandard system.baseUUID networking.hostName";
      default = namespacedUUIDNonStandard config.system.baseUUID config.networking.hostName;
    };
    system.rootfsUUID = mkOption {
      description = ''
        UUID of root file system
      '';
      type = uuidType;
      defaultText = "namespacedUUIDNonStandard system.systemUUID \"rootfs\"";
      default = namespacedUUIDNonStandard config.system.systemUUID "rootfs";
    };
    system.rootPartitionUUID = mkOption {
      description = ''
        UUID of root partition
      '';
      type = uuidType;
      defaultText = "namespacedUUIDNonStandard system.systemUUID \"rootPartition\"";
      default = namespacedUUIDNonStandard config.system.systemUUID "rootPartition";
    };
  };

  config = {
    fileSystems."/" = mkDefault {
      device = "/dev/disk/by-uuid/${config.system.rootfsUUID}";
      fsType = "ext4";
    };

    system.build.orangepi-installer-info = mkDefault {
      script = ./install-sd-allwinner;
      inherit (config.system.build) u-boot toplevel;
      inherit (config.networking) hostName;
      inherit (config.system) systemUUID rootfsUUID rootPartitionUUID;
      extlinuxPopulateCmd = config.boot.loader.generic-extlinux-compatible.populateCmd;
    };
    system.build.orangepi-installer =
      let info = config.system.build.orangepi-installer-info; in
      pkgs.runCommand "orangepi-installer" {
        inherit (info) script;
        infoJSON = toJSON info;
        infoShell = ''
          declare -A info
        '' + (concatStrings (mapAttrsToList (k: v: "info[${k}]=${escapeShellArg v}\n") info));
        passAsFile = [ "infoJSON" "infoShell" ];
      } ''
        mkdir $out
        ln -s $script $out/install
        cp $infoJSONPath $out/info.json
        cp $infoShellPath $out/info.zsh
      '';
  };
}
