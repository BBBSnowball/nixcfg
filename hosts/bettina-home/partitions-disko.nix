# sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.2.0 -- --mode disko /tmp/partitions-disko.nix
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-path/pci-0000:00:12.0-ata-1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1024M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };
 
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "10G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };
          nix-store = {
            size = "30G";
            content = {
              type = "filesystem";
              format = "ext4";
              # Nix store often has many small files so reserve more space for inodes.
              # (default is one inode per 16k)
              extraArgs = [ "-i${toString (16384 / 4)}" ];
              mountpoint = "/nix/store";
            };
          };
        };
      };
    };
  };
}
