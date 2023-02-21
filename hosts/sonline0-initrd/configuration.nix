{ lib, pkgs, config, ... }:
let
  debugInQemu = config.boot.initrd.debugInQemu;
  private = import ./private.nix { inherit debugInQemu; };
  iface = if debugInQemu then "ens3" else "enp1s0f0";
in
{
  imports = [ ./hardware-configuration.nix ./debug.nix ];
  time.timeZone = "Europe/Berlin";
  system.stateVersion = "22.11";
  networking.hostName = "sonline0";

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
      inherit (private) port authorizedKeys;
      hostKeys = [ "${private.secretDir}/ssh_host_rsa_key" ];
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
    ] ++ (if !debugInQemu then [] else [
      # for testing in qemu
      "virtio_pci" "virtio_blk" "virtio_net"
      "e1000e"
    ]);


    secrets."/etc/dhcp/dhclient6.conf" = "${private.secretDir}/dhclient6.conf";
    secrets."/etc/secretenv" = "${private.secretDir}/secretenv";
    secrets."/var/lib/dhcpcd/duid" = "${private.secretDir}/duid";
    secrets."/var/db/dhcpcd/duid" = "${private.secretDir}/duid";
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
      #sh -i
    '';

    #debugInQemu = true;
  };
}

# files in secret dir:
# ( umask 077; mkdir secret )
# ssh-keygen -t rsa -N "" -b 4096 -f secrets/ssh_host_rsa_key
# secret/dhclient6.conf:
#   interface "enp1s0f0" {
#       send dhcp6.client-id DUID;
#   }
# (with DUID replaced by what the Scaleway web interfaces shows for the IPv6 block)
# secret/secretenv:
# ipv6=2001:2:3:4::123
# private.nix:
#   {
#     port = 22;
#     authorizedKeys = [ "ssh-rsa ..." ];
#     secretDir = "/path/to/this/dir/secret";  # make sure to specify it as a string
#     #secretDir = "$secrets";  # set $secret when running the secret appender script -> not allowed, it seems
#   }

