{ lib, pkgs, config, private, ... }:
let
  testInQemu = config.boot.initrd.testInQemu;
  privateValues = import "${private}/by-host/${config.networking.hostName}/initrd.nix" { inherit testInQemu; };
  inherit (privateValues) secretDir;
  iface = if testInQemu then "ens3" else "enp1s0f0";
in
{
  imports = [ ./hardware-configuration.nix ./debug.nix ];
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
    ];
  in {
    network.enable = true;
    network.ssh = {
      enable = true;
      inherit (privateValues) port authorizedKeys;
      hostKeys = [ "${secretDir}/ssh_host_rsa_key" ];
      extraConfig = ''
        Subsystem sftp ${pkgs.openssh}/libexec/sftp-server
      '';
    };
    extraUtilsCommands = ''
      for x in ${toString (builtins.map lib.getExe extraBin)} ; do
        copy_bin_and_libs $x
      done
    '';
  
    availableKernelModules = [
      "sd_mod" "igb" "dm-snapshot"
      "ipmi_devintf" "ipmi_si" "ipmi_ssif"
    ] ++ (if !testInQemu then [] else [
      # for testing in qemu
      "virtio_pci" "virtio_blk" "virtio_net"
      "e1000e"
    ]);


    secrets."/etc/secretenv" = "${secretDir}/secretenv";
    secrets."/var/lib/dhcpcd/duid" = "${secretDir}/duid";
    secrets."/var/db/dhcpcd/duid" = "${secretDir}/duid";
    network.postCommands = lib.mkAfter ''
      # https://www.scaleway.com/en/docs/dedibox-network/ipv6/quickstart/
      #dhcpd -cf /etc/dhcp/dhclient6.conf -6 -P -v enp1s0f0
      # -> not supported anymore for NixOS because it is end-of-life
      # https://www.scaleway.com/en/docs/tutorials/dhcpcd-dedibox/
      mkdir -p /var/db /var/run
      ${pkgs.dhcpcd}/bin/dhcpcd -6 -f ${./dhcpcd.conf}

      source /etc/secretenv
      ip -6 a add $ipv6/56 dev ${iface}

      sleep inf
    '';
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
#   }

