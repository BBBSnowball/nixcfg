# ls -1 /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_* | grep -v '[-]part\|_1$' | xargs -i{} ln -s {} /dev/alias-ssd1
# ls -1 /dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_* | grep -v '[-]part\|_1$' | xargs -i{} ln -s {} /dev/alias-ssd2
# modprobe dm-raid   # otherwise lvcreate will complain about raid1
# sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.6.1 -- --mode disko /tmp/partitions-disko.nix
with builtins;
let
  makeSSD = num: {
    device = "/dev/alias-ssd${toString num}";
    content = {
      type = "gpt";
      partitions = {
        MBR = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };
        ESP = {
          #type = "EF00";
          size = "1024M";
          content = {
            type = "mdraid";
            name = "ESP";
          };
        };
        # systemd bootctl refuses to work with raid, so let's create another ESP, for now.
        # see https://systemd-devel.freedesktop.narkive.com/3gjOshj3/bootctl-install-on-mdadm-raid-1-fails
        "ESP${toString num}" = {
          type = "EF00";
          size = "1024M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot${if num == 1 then "" else toString num}";
            mountOptions = [
              "fmask=0137,dmask=0027"
            ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "lvm_pv";
            vg = "ssd";
          };
        };
      };
    };
  };

  makeHDD = num: {
    device = "/dev/disk/by-path/pci-0000:5a:00.0-ata-${toString num}.0";
    content = {
      type = "gpt";
      partitions = {
        root = {
          size = "100%";
          content = {
            type = "lvm_pv";
            vg = "hdd";
          };
        };
      };
    };
  };

  lvOnSpecificPv = { pv, vg, ... }@args: (removeAttrs args ["pv" "vg"]) // {
    # We can create the LV on specific PVs by passing them as additional arguments.
    # Unfortunately, disko will insert them before the VG name, so we have to cheat.
    #extraArgs = [ pv ];
    extraArgs = [
      vg
      "'${replaceStrings [":"] ["\\:"] pv}'"
      #";#"
      "; fi; if false ; then #"
    ];
  };
in
{
  disko.devices = rec {
    disk = {
      ssd1 = makeSSD 1;
      ssd2 = makeSSD 2;
      disk1 = makeHDD 1;
      disk2 = makeHDD 2;
    };
    
    mdadm = {
      ESP = {
        type = "mdadm";
        level = 1;
        # put metadata at the end and omit write-intent bitmap, so BIOS can use the partition without
        # knowing about raid
        # see https://unix.stackexchange.com/questions/644108/raid-1-of-boot-efi-partition-on-debian
        # (The alternative is to let grub mirror to a 2nd ESP but that won't work with systemd-boot and lanzaboote.)
        metadata = "1.0";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot-raid";
          mountOptions = [
            "fmask=0137,dmask=0027"
          ];
        };
      };
    };
 
    lvm_vg = {
      ssd = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "300G";
            # Let's put raid1 below luks (instead of letting btrfs do it) to avoid
            # encrypting data twice.
            lvm_type = "raid1";
            content = {
              type = "luks";
              name = "root";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = let
                  mountOptions = [ "compress=zstd" "noatime" ];
                in {
                  "/root" = {
                    mountpoint = "/";
                    inherit mountOptions;
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    inherit mountOptions;
                  };
                };
              };
            };
          };

          # create partitions for bcachefs (which we will manually create later)
          fast1 = lvOnSpecificPv {
            vg = "ssd";
            #pv = disk.ssd1.content.partitions.root.device;
            #pv = "/dev/nvme0n1p3";
            pv = "/dev/disk/by-partlabel/disk-ssd1-root";
            size = "1TB";
          };
          fast2 = lvOnSpecificPv {
            vg = "ssd";
            #pv = disk.ssd2.content.partitions.root.device;
            pv = "/dev/disk/by-partlabel/disk-ssd2-root";
            size = "1TB";
          };
        };
      };

      hdd = {
        type = "lvm_vg";
        lvs = {
          slow1 = lvOnSpecificPv {
            vg = "hdd";
            pv = "${disk.disk1.device}-part1";
            size = "1TB";
          };
          slow2 = lvOnSpecificPv {
            vg = "hdd";
            pv = "${disk.disk2.device}-part1";
            size = "1TB";
          };
        };
      };
    };
  };
}
