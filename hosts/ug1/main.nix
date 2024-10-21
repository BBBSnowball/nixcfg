{ config, pkgs, lib, routeromen, privateForHost, nixos-hardware, lanzaboote, ... }@args:
let
  #tinc-a-address = "192.168.83.139";
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      ssh-github
      allowUnfree
    ] ++ [
      ./audiobookshelf.nix
      ./bcachefs.nix
      ./disko.nix
      ./hardware-configuration.nix
      lanzaboote.nixosModules.lanzaboote
      ./secureBoot.nix
      ./ugreen.nix
      ./users.nix
    ];

  networking.hostName = "ug1";

  # If raid logical volume is not available, do: `modprobe dm-raid; vgchange -a y`
  boot.initrd.availableKernelModules = [ "dm_raid" ];
  boot.initrd.kernelModules = [ "dm_raid" "hid_roccat_ryos" ];  #FIXME does adding roccat module help?
  boot.initrd.services.lvm.enable = true;
  boot.initrd.systemd.enable = true;  # will interfere with boot.shell_on_fail
  # see https://github.com/NixOS/nixpkgs/issues/245089#issuecomment-1646966283
  boot.initrd.systemd.emergencyAccess = true;  #FIXME remove when we enable secure boot
  # for debugging
  boot.kernelParams = [ "boot.shell_on_fail" ];
  console.earlySetup = true;  #FIXME does this help? -> Yes! It also fixes the issue with devices not being found. -> Well, no. That was just coincidence.
  #FIXME for debugging initrd, remove later
  #FIXME This is added to the config but it doesn't change the timeout.
  #boot.initrd.systemd.extraConfig = ''
  #  DefaultTimeoutStartSec = 20
  #'';
  # dm-raid to avoid: "Can't process LV ssd/root: raid1 target support missing from kernel?"
  boot.initrd.systemd.services.mdmonitor.serviceConfig.ExecStartPre = [
    "${lib.getBin pkgs.kmod}/bin/modprobe dm_raid"
  ];
  # auto-activate "ssd" volume group again (in case the VG service ran before we were able to add the kernel module)
  boot.initrd.systemd.services.mdmonitor.serviceConfig.ExecStartPost = [
    "${lib.getBin pkgs.lvm2}/bin/lvm vgchange -aay --autoactivation event ssd"
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.allowUnfreeByName = [
    "memtest86-efi"
  ];

  # Avoid seed being stored in word accessible location. These are the bootctl warnings for this:
  #   Mount point '/boot' which backs the random seed file is world accessible, which is a security hole!
  #   Random seed file '/boot/loader/random-seed' is world accessible, which is a security hole!
  # see https://forum.endeavouros.com/t/bootctl-install-outputs-some-warnings-about-efi-mount-point-and-random-seed-file-in-the-terminal/43991/6
  fileSystems."/boot".options = [
    "fmask=0137,dmask=0027"
  ];
  fileSystems."/boot2".options = [
    "fmask=0137,dmask=0027"
  ];
  fileSystems."/boot-raid".options = [
    "fmask=0137,dmask=0027"
  ];

  networking.useNetworkd = true;

  networking.useDHCP = false;
  networking.interfaces.enp88s0.useDHCP = true;
  networking.interfaces.enp89s0.useDHCP = true;
  systemd.network.wait-online.extraArgs = [ "--any" ];
  systemd.network.wait-online.timeout = 10;

  nix.registry.routeromen.flake = routeromen;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    #"riscv32-linux"  # would build qemu. yuck.
    #"riscv64-linux"
    "wasm32-wasi"
    "wasm64-wasi"
  ];

  environment.systemPackages = with pkgs; [
  ];

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  programs.emacs.defaultEditor = lib.mkForce false;
  programs.vim.defaultEditor = true;

  # -> hard fail without Polkit because it refuses to continue when the policy files are missing:
  # https://github.com/fwupd/fwupd/blob/e995cb55a294ba2a9200cf1a8e6b29b3442dbbb4/src/fu-util.c#L4170
  #services.fwupd.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # mdmonitor service is added by mdadm package and it will fail if we don't configure this.
  # (msmtp will resolve "root" to the intended recipient via aliases.)
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  services.tailscale.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
