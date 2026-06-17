# This script formats a host, mounts the partitions, runs nixos-generate-config
# and then returns a summary that can be used to specialize the system
# configuration for the machine.

{ pkgs ? import <nixpkgs> {}, hostname, template }:

with builtins; with pkgs;
let
  zsh-bin = "${zsh}/bin/zsh";
  realpath-bin = "${coreutils}/bin/realpath";
  lsblk-bin = "${utillinux}/bin/lsblk";
  blkid-bin = "${utillinux}/bin/blkid";
  blkdiscard-bin = "${utillinux}/bin/blkdiscard";
  sfdisk-bin = "${utillinux}/bin/sfdisk";
  mkswap-bin = "${utillinux}/bin/mkswap";
  swapon-bin = "${utillinux}/bin/swapon";
  mount-bin = "${utillinux}/bin/mount";
  umount-bin = "${utillinux}/bin/umount";
  cryptsetup-bin = "${cryptsetup}/bin/cryptsetup";
  pvcreate-bin = "${lvm2.bin}/bin/pvcreate";
  lvcreate-bin = "${lvm2.bin}/bin/lvcreate";
  vgcreate-bin = "${lvm2.bin}/bin/vgcreate";
  mkfs-fat-bin = "${dosfstools}/bin/mkfs.fat";
  mkfs-ext4-bin = "${e2fsprogs}/bin/mkfs.ext4";
  mkfs-btrfs-bin = "${btrfsProgs}/bin/mkfs.btrfs";
  btrfs-bin = "${btrfsProgs}/bin/btrfs";
  fzf-bin = "${fzf}/bin/fzf";
  jq-bin = "${jq}/bin/jq";
  partprobe-bin = "${busybox}/bin/partprobe";

  swap = (if template ? swap then template.swap else "8G");
  luks = template.luks;

in
assert (typeOf luks) == "bool";
assert (typeOf swap) == "string";
{
  configure = writeScriptBin "configure" ''
    #!${zsh-bin}
    set -e
    set -u
    set -o pipefail

    ${if luks then ''
      read -r -s "luks?Please enter the new LUKS passphrase:"
    '' else ""}

    # Generate config
    <<EOF
    {
      "blockDevice": null
      ${if luks then ''
        ,"luksKey": "$luks"
      '' else ""}
    }
    EOF
    luks_key=""
  '';

  # Helper script that has to be run on the target machine to format it
  format = writeScriptBin "format" ''
    #!${zsh-bin}
    set -e
    set -u
    set -o pipefail

    source ${./util.zsh}

    cmdname=$0
    usage() {
      print "Usage: $cmdname <CONFIG_FILE> <OUTPUT_FILE>" >&2
    }

    if [ "$1" = "--help" -o "$1" = "-h" ]
    then
        usage
        exit 0
    fi

    if [ $# -ne 2 -a $# -ne 3 ]
    then
      print "Invalid number of arguments." >&2
      usage
      exit 2
    fi

    config_file="$1"
    output_file="$2"

    # Before doing anything that could fail:
    # Set up tmpdir controlled by this script (and trap to remove it) and move the
    # installation config there to make sure it is deleted if the script fails in
    # any way.
    temp_dir=$(mktemp --tmpdir --directory install.nix.XXXXXXXXXX)
    trap "rm -rf $temp_dir" EXIT INT HUP TERM
    mv $config_file $temp_dir/config
    config_file=$temp_dir/config

    block_device=$(${jq-bin} --raw-output .blockDevice $config_file)
    if [ "$block_device" = null ]
    then
      block_device=$(${lsblk-bin} --nodeps --output PATH,NAME,SIZE,TYPE,MODEL,VENDOR | ${fzf-bin} --layout=reverse --header-lines=1 --nth=1 | awk '{print $1;}')
    fi

    if [ ! -b "$block_device" ]
    then
      print_info "error: $block_device is not a block device."
      exit 1
    fi

    print_info "Selected block device: $block_device"

    stable_block_device=$(for i in /dev/disk/by-id/*; do [ "$(${realpath-bin} "$i")" = "$(${realpath-bin} "$block_device")" ] && echo "$i" && return; done)

    print_info "Stable block device name is: $stable_block_device"
    print_info

    print_info "Printing old layout of target block device:"
    print_info "$(${lsblk-bin} --output name,size,type,mountpoint,model,vendor "$block_device")"
    print_info


    print_info "You are about to install the configuration for host '${hostname}' to $block_device (this is executed on host '$(hostname)')."
    if read -q "?Do you want to WIPE ALL DATA on $block_device? (y/n) "
    then
      print >&2
    else
      print >&2
      exit 3
    fi

    print_info "Wiping partition table"
    dd if=/dev/zero of=$block_device bs=1M count=1 conv=fsync

    # Ensure partition table changes have been registered by the kernel
    ${partprobe-bin} $block_device

    print_info "Discarding disk contents"
    if ${blkdiscard-bin} $block_device
    then
      ssd=true
    else
      ssd=false
      print_warning "Discard failed, disabling ssd configuration"
    fi

    print_info "Creating partition table for bootloader ${template.bootloader}"

    ${if template.bootloader == "efi" then ''
      ${if luks then ''
        ${sfdisk-bin} "$block_device" <<EOF
          label: gpt
          start=2048, size=512MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="esp"
          type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
        EOF
        esp_partition="$block_device"1
        luks_partition="$block_device"2
      '' else ''
        ${sfdisk-bin} "$block_device" <<EOF
          label: gpt
          start=2048, size=512MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="esp"
          size=${swap}iB,type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="swap"
          type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
        EOF
        esp_partition="$block_device"1
        swap_partition="$block_device"2
        root_partition="$block_device"3
      ''}
    '' else if template.bootloader == "bios" then ''
      ${if luks then ''
        ${sfdisk-bin} "$block_device" <<EOF
          label: gpt
          size=1MiB, type=21686148-6449-6E6F-744E-656564454649, name="bios_grub"
          size=512MiB, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
          type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
        EOF
        esp_partition="$block_device"2
        luks_partition="$block_device"3
      '' else ''
        ${sfdisk-bin} "$block_device" <<EOF
          label: gpt
          size=1MiB, type=21686148-6449-6E6F-744E-656564454649, name="bios_grub"
          size=512MiB, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="boot"
          size=${swap}iB,type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="swap"
          type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="system"
        EOF
        esp_partition="$block_device"2
        swap_partition="$block_device"3
        root_partition="$block_device"4
      ''}
    '' else abort "Invalid bootloader configured in template: ${template.bootloader}" }

    # Ensure partition table changes have been registered by the kernel
    ${partprobe-bin} $block_device

    print_info "Creating partitions"

    ${mkfs-fat-bin} -F32 -n ESP "$esp_partition"

    ${if luks then ''
      luks_keyfile=$temp_dir/luksKey
      luks_key=$(${jq-bin} -e --raw-output .luksKey $config_file)
      print -n "$luks_key" > $luks_keyfile

      ${cryptsetup-bin} --batch-mode --key-file $luks_keyfile luksFormat --type luks2 $luks_partition

      luks_partition_uuid=$(${blkid-bin} --match-tag UUID --output value $luks_partition)
      if [[ -z $luks_partition_uuid ]]
      then
        print_error "Cound not detect uuid of luks partition" >&2
        exit 1
      fi

      crypt_volume_name=cryptvol_${hostname}

      if $ssd
      then
        ${cryptsetup-bin} --batch-mode --key-file $luks_keyfile --allow-discards --persistent open $luks_partition $crypt_volume_name
      else
        ${cryptsetup-bin} --batch-mode --key-file $luks_keyfile open $luks_partition $crypt_volume_name
      fi

      rm $luks_keyfile

      lvm_partition=/dev/mapper/$crypt_volume_name

      vg_name=vg_${hostname}

      ${pvcreate-bin} $lvm_partition
      ${vgcreate-bin} $vg_name $lvm_partition

      ${lvcreate-bin} --size "${swap}" --name swap --yes $vg_name
      swap_partition="/dev/$vg_name/swap"
      ${lvcreate-bin} --extents "100%FREE" --name btrfs --yes $vg_name
      root_partition="/dev/$vg_name/btrfs"
    '' else ""}

    ${mkswap-bin} -L swap $swap_partition
    ${swapon-bin} $swap_partition

    ${mkfs-btrfs-bin} -L "btrfs_${hostname}" "$root_partition"

    mount_point=/mnt

    mkdir -p $mount_point

    if $ssd
    then
      mountflags=noatime,discard=async
    else
      mountflags=noatime
    fi

    # Create subvolumes
    ${mount-bin} -o $mountflags $root_partition $mount_point
    ${btrfs-bin} subvolume create $mount_point/${hostname}
    ${btrfs-bin} subvolume create $mount_point/${hostname}/nix
    ${umount-bin} $mount_point

    # Remount
    ${mount-bin} -o subvol=/${hostname},$mountflags $root_partition $mount_point

    mkdir -p $mount_point/boot
    ${mount-bin} -o noatime $esp_partition $mount_point/boot

    if [[ -d /nix/.rw-store ]]
    then
      print_info "Nix store tmpfs-rw-overlay detected, increasing tmpfs size"
      mount -o remount,size=8G /nix/.rw-store
    fi

    print_info "Generating NixOS hardware config"
    nixos-generate-config --root $mount_point

    print_info "Writing output"
    > "$output_file" <<EOF
    {
      "installedBlockDevice": "$stable_block_device",
      "luks": ${toJSON luks},
      ${if luks then ''
        "luksPartitionUuid": "$luks_partition_uuid",
      '' else ""}
      "ssd": $ssd,
      "bootloader": "${template.bootloader}"
    }
    EOF

    print_info "Installation stage 1 completed"
  '';
}
