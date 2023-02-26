{ lib, pkgs, config, private, nixpkgs, ... }:
let
  inherit (config.boot.initrd) testInQemu withNix;
  privateValues = import "${private}/by-host/${config.networking.hostName}/initrd.nix" { inherit testInQemu; };
  inherit (privateValues) secretDir;
  iface = if testInQemu then "ens3" else "enp1s0f0";

  passphrase = pkgs.writeShellScriptBin "passphrase" ''
    echo "$1" >/crypt-ramfs/passphrase
  '';
in
{
  imports = [ ./hardware-configuration.nix ./config.nix ];
  time.timeZone = "Europe/Berlin";
  system.stateVersion = "22.11";

  services.openssh = {
    # some options from here are also used for the initrd, e.g. useDns - but we keep the defaults, for now
    enable = true;
  };

  # https://nixos.wiki/wiki/Remote_LUKS_Unlocking
  boot.initrd = let
    extraBin = with pkgs; [
      dmraid mdadm cryptsetup
      (lvm2 // { meta.mainProgram = "lvm"; })
      dhcpcd
      (kexec-tools // { meta.mainProgram = "kexec"; })
      lshw
      (usbutils // { meta.mainProgram = "lsusb"; })
      (util-linux // { meta.mainProgram = "lsblk"; })
    ];
    # extraBin adds them without the replaced paths for some reason so we add them in postCommands, instead.
    extraBin2 = if !withNix then [] else with pkgs; [
      pkgs.nix
      config.system.build.nixos-generate-config
      config.system.build.nixos-install
      curl
      #strace
      libxfs.bin  # makeBinPath would choose .dev
      e2fsprogs
      tmux
      byobu
      gnupg
      duplicity
      btrfs-progs
      util-linux  # fdisk
      duplicity
      gnupg
      grub2
      passphrase
    ];
  in {
    network.enable = true;
    network.ssh = {
      enable = true;
      inherit (privateValues) port authorizedKeys;
      hostKeys = [ "${secretDir}/ssh_host_rsa_key" ];
      extraConfig = let
        extraUtils = config.system.build.bootStage1.extraUtils;
      in ''
        Subsystem sftp ${pkgs.openssh}/libexec/sftp-server
      '' + (if extraBin2 == [] then "" else ''
        #NOTE We have to set it here because /etc/profile will not be evaluated in a non-interactive shell
        #     and we need nix-store on the path for nix-copy-closure.
        SetEnv PATH=${nixpkgs.lib.makeBinPath extraBin2}:/bin
        #SetEnv LD_LIBRARY_PATH=''${extraUtils}/lib  # would cause infinite recursion
      '');
    };
    extraUtilsCommands = ''
      for x in ${toString (builtins.map lib.getExe extraBin)} ; do
        copy_bin_and_libs $x
      done
    '';
  
    availableKernelModules = [
      "sd_mod" "igb" "dm-snapshot"
      "ipmi_devintf" "ipmi_si" "ipmi_ssif"
      "btrfs"
      "dm_mod" "dm_crypt" "cryptd" "input_leds"  # luks
      "aesni_intel" "crc32c_intel" # high-speed crypto
      "usb_storage" "isofs"  # supermicro virtual drive
    ] ++ (if !testInQemu then [] else [
      # for testing in qemu
      "virtio_pci" "virtio_blk" "virtio_net"
      "e1000e"
    ]);


    secrets."/etc/secretenv" = "${secretDir}/secretenv";
    secrets."/var/lib/dhcpcd/duid" = "${secretDir}/duid";
    secrets."/var/db/dhcpcd/duid" = "${secretDir}/duid";
    network.postCommands = lib.mkMerge [(lib.mkBefore (lib.optionalString withNix ''
      #NOTE nix will not be fully functional because it fails to do its /real-root mount
      #     tricks with the initramfs:
      #     error: cannot pivot old root directory onto '/nix/store/*.drv.chroot/real-root': Invalid argument
      export PATH=${nixpkgs.lib.makeBinPath extraBin2}:$PATH

      mkdir -p /etc/ssl/certs
      ln -s ${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/
      ln -s ca-bundle.crt $out/etc/ssl/certs/ca-certificates.crt
      ln -s ${pkgs.cacert.p11kit}/etc/ssl/trust-source $out/etc/ssl/trust-source
    '')) (lib.mkAfter (lib.optionalString withNix ''
      # We must do this after the commands that the SSH module adds to init /etc/passwd.
      # That's why it is in the mkAfter part.
      users=""
      for i in `seq 32` ; do
        echo "nixbld$i:x:$((30000+$i)):30000:Nix build user $i:/var/empty:$(which nologin)" >>/etc/passwd
        users=$users,nixbld$i
      done
      echo "nixbld:x:30000:nixbld1$users" >>/etc/group
    '')) (lib.mkAfter ''
      # https://www.scaleway.com/en/docs/dedibox-network/ipv6/quickstart/
      #dhcpd -cf /etc/dhcp/dhclient6.conf -6 -P -v enp1s0f0
      # -> not supported anymore for NixOS because it is end-of-life
      # https://www.scaleway.com/en/docs/tutorials/dhcpcd-dedibox/
      mkdir -p /var/db /var/run
      ${pkgs.dhcpcd}/bin/dhcpcd -6 -f ${./dhcpcd.conf} &

      source /etc/secretenv
      ip -6 a add $ipv6/56 dev ${iface}

      # The init script will wait for us to paste a passphrase into /crypt-ramfs/passphrase
      # but only if we have configured some luks device. We used to sleep here but that should
      # not be necessary anymore.
      #${if testInQemu then "sleep inf" else ""}
    '')];

    luks.devices = lib.listToAttrs (lib.imap1 (i: id: lib.nameValuePair "luks${toString i}" {
      device = "/dev/disk/by-id/${id}-part2";
      allowDiscards = true;
      # https://wiki.archlinux.org/title/Dm-crypt/Specialties#Disable_workqueue_for_increased_solid_state_drive_(SSD)_performance
      bypassWorkqueues = true;
    }) privateValues.disk-ids);
  };
}

# files in secret dir:
# ( umask 077; mkdir secret )
# ssh-keygen -t rsa -N "" -b 4096 -f secrets/ssh_host_rsa_key
# secret/secretenv:
#   ipv4=1.2.3.4
#   ipv6=2001:2:3:4::123
# private/initrd.nix:
#   { testInQemu }:
#   {
#     port = 22;
#     authorizedKeys = [ "ssh-rsa ..." ];
#     secretDir = "/etc/nixos/secret/by-host/sonline0-initrd";  # make sure to specify it as a string
#     disk-ids = [ "ata-something-something" ];  # name in /dev/disk/by-id
#   }

# How to use nix-copy-closure:
# NIX_SSHOPTS="-F result-initrd-test/ssh_config -i ~/.ssh/id_sonline0" nix-copy-closure --store /asdf --to initrd-test path
# NIX_SSHOPTS="-F result-initrd-test/ssh_config -i ~/.ssh/id_sonline0" nix copy --to ssh://initrd-test path
# This one would be very useful but it doesn't work:
# NIX_SSHOPTS="-F result-initrd-test/ssh_config -i ~/.ssh/id_sonline0" nix copy --to ssh://initrd-test?store=/mnt/nix path
#
# NIX_SSHOPTS="-F result-initrd/ssh_config -i ~/.ssh/id_sonline0" nix copy --to ssh://initrd nixpkgs#lftp

