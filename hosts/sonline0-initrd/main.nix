{ lib, pkgs, config, private, nixpkgs, ... }:
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
      curl
      #nix
      #(nix // { meta.mainProgram = "nix-store"; })
      #(nix // { meta.mainProgram = "nix-shell"; })
      #strace

      # This adds them without the replaced paths for some reason so we add them in postCommands, instead.
      #(nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = []; }).config.system.build.nixos-generate-config
      #(nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = []; }).config.system.build.nixos-install
      #config.system.build.nixos-generate-config
      #config.system.build.nixos-install
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

        #NOTE We have to set it here because /etc/profile will not be evaluated in a non-interactive shell
        #     and we need nix-store on the path for nix-copy-closure.
        SetEnv PATH=/bin:${nixpkgs.lib.makeBinPath [
          #extraUtils
          pkgs.nix
          (nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = []; }).config.system.build.nixos-generate-config
          (nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = []; }).config.system.build.nixos-install
        ]}
        #SetEnv LD_LIBRARY_PATH=''${extraUtils}/lib  # would cause infinite recursion
      '';
    };
    extraUtilsCommands = ''
      for x in ${toString (builtins.map lib.getExe extraBin)} ; do
        copy_bin_and_libs $x
      done

      if false ; then
        mkdir -p $out/etc/ssl/certs
        cp ${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/
        ln -s ca-bundle.crt $out/etc/ssl/certs/ca-certificates.crt
        cp -r ${pkgs.cacert.p11kit}/etc/ssl/trust-source $out/etc/ssl/trust-source
      fi

      #cp -s ${lib.getBin pkgs.nix}/bin/* $out/bin/
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
    network.postCommands = lib.mkMerge [(lib.mkBefore ''
      #NOTE nix will not be fully functional because it fails to do its /real-root mount
      #     tricks with the initramfs:
      #     error: cannot pivot old root directory onto '/nix/store/*.drv.chroot/real-root': Invalid argument
      export PATH=$PATH:${lib.getBin pkgs.nix}/bin
      export PATH=$PATH:${(nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = []; }).config.system.build.nixos-generate-config}/bin
      export PATH=$PATH:${(nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = []; }).config.system.build.nixos-install}/bin
      export PATH=$PATH:${lib.getBin libxfs}/bin
      #echo "SetEnv PATH=$PATH" >>/etc/ssh/sshd_config

      mkdir -p /etc/ssl/certs
      ln -s ${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/
      ln -s ca-bundle.crt $out/etc/ssl/certs/ca-certificates.crt
      ln -s ${pkgs.cacert.p11kit}/etc/ssl/trust-source $out/etc/ssl/trust-source
    '') (lib.mkAfter ''
      # We must do this after the commands that the SSH module adds to init /etc/passwd.
      # That's why it is in the mkAfter part.
      users=""
      for i in `seq 32` ; do
        echo "nixbld$i:x:$((30000+$i)):30000:Nix build user $i:/var/empty:$(which nologin)" >>/etc/passwd
        users=$users,nixbld$i
      done
      echo "nixbld:x:30000:nixbld1$users" >>/etc/group

      # https://www.scaleway.com/en/docs/dedibox-network/ipv6/quickstart/
      #dhcpd -cf /etc/dhcp/dhclient6.conf -6 -P -v enp1s0f0
      # -> not supported anymore for NixOS because it is end-of-life
      # https://www.scaleway.com/en/docs/tutorials/dhcpcd-dedibox/
      mkdir -p /var/db /var/run
      ${pkgs.dhcpcd}/bin/dhcpcd -6 -f ${./dhcpcd.conf} &

      source /etc/secretenv
      ip -6 a add $ipv6/56 dev ${iface}

      sleep inf
    '')];
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

# How to use nix-copy-closure:
# NIX_SSHOPTS="-F result-initrd-test/ssh_config -i ~/.ssh/id_sonline0" nix-copy-closure --store /asdf --to initrd-test path
# NIX_SSHOPTS="-F result-initrd-test/ssh_config -i ~/.ssh/id_sonline0" nix copy --to ssh://initrd-test path
# This one would be very useful but it doesn't work:
# NIX_SSHOPTS="-F result-initrd-test/ssh_config -i ~/.ssh/id_sonline0" nix copy --to ssh://initrd-test?store=/mnt/nix path

