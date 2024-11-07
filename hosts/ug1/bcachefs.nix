{ lib, pkgs, ... }:
let
  # bcachefs show-super /dev/ssd/ssd1 | gawk '/^Device:/ { d=1 }; /^  Label:/ { l=$2 }; /^  UUID:/ { print "\"" $2 "\"  # " l }'
  # -> nope. not a uuid that systemd knows about...
  #toDeviceUnit = uuid: "UUID\\x3d" + builtins.replaceStrings ["-"] ["\\x2d"] uuid + ".device";
  #toDeviceUnit = uuid: "dev-disk-by\\x2duuid-" + builtins.replaceStrings ["-"] ["\\x2d"] uuid + ".device";
  #devices.data = map toDeviceUnit [ ... ];

  # Well, systemd knows about our LV labels, so let's use them.
  devices.data = [
    "dev-hdd-hdd1.device"
    "dev-hdd-hdd2.device"
    "dev-hdd-hdd3.device"
    "dev-ssd-ssd1.device"
    "dev-ssd-ssd2.device"
  ];
  devices.sdata = [
    "dev-hdd-hdd1e.device"
    "dev-hdd-hdd2e.device"
    "dev-hdd-hdd3e.device"
    "dev-ssd-ssd1e.device"
    "dev-ssd-ssd2e.device"
  ];
in
{
  boot.supportedFilesystems = [ "bcachefs" ];

  fileSystems."/media/data".options = [ "nofail,x-systemd.automount" ];
  fileSystems."/media/sdata".options = [ "nofail,x-systemd.automount" ];

  # unlock by UUID instead of device name will fail but that one is unencrypted anyway
  # -> Actually, this fails in more places, so we better refer to one of the constituating disks in the mount anyway.
  #systemd.services.unlock-bcachefs-media-data.serviceConfig.ExecCondition = lib.mkForce ''${pkgs.coreutils}/bin/false'';
  #systemd.services.unlock-bcachefs-media-data.serviceConfig.ExecStart = lib.mkForce ''${pkgs.coreutils}/bin/true'';
  # unlock must use the key file, not ask for password on tty
  #systemd.services.unlock-bcachefs-media-sdata.serviceConfig.ExecCondition = lib.mkForce ''${pkgs.coreutils}/bin/true'';
  systemd.services.unlock-bcachefs-media-sdata.serviceConfig.ExecStart = lib.mkForce
    ''${pkgs.bcachefs-tools}/bin/bcachefs unlock -f /etc/nixos/secret_local/bcachefs_key /dev/ssd/ssd1e'';

  # Dependencies try to use the filesystem ID because that's what we use for the mount.
  # That's no good because it will never appear as a block device, so let's replace that.
  systemd.services.unlock-bcachefs-media-data.after = lib.mkForce devices.data;
  systemd.services.unlock-bcachefs-media-data.bindsTo = lib.mkForce devices.data;
  systemd.services.unlock-bcachefs-media-sdata.after = lib.mkForce devices.sdata;
  systemd.services.unlock-bcachefs-media-sdata.bindsTo = lib.mkForce devices.sdata;
}
