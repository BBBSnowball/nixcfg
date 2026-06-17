{ pkgs, ... }:
let
  ioschedulers-udev = pkgs.writeTextDir "/etc/udev/rules.d/60-ioschedulers.rules" ''
    # set scheduler for NVMe
    ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="bfq"
    # set scheduler for SSD and eMMC
    ACTION=="add|change", KERNEL=="[sv]d[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
    # set scheduler for rotating disks
    ACTION=="add|change", KERNEL=="[sv]d[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

in
{
  services.udev.packages = [ ioschedulers-udev ];
}
