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
    ] ++
    [ ./hardware-configuration.nix
      ./users.nix
      ./disko.nix
      #./secureBoot.nix
      #lanzaboote.nixosModules.lanzaboote
    ];

  networking.hostName = "ug1";

  # If raid logical volume is not available, do: `modprobe dm-raid; vgchange -a y`
  boot.initrd.availableKernelModules = [ "dm_raid" ];
  boot.initrd.kernelModules = [ "dm_raid" ];
  boot.initrd.services.lvm.enable = true;
  boot.initrd.systemd.enable = true;  # will interfere with boot.shell_on_fail
  # see https://github.com/NixOS/nixpkgs/issues/245089#issuecomment-1646966283
  boot.initrd.systemd.emergencyAccess = true;  #FIXME remove when we enable secure boot
  # for debugging
  boot.kernelParams = [ "boot.shell_on_fail" ];

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
    #FIXME This is ignored here (but works for bettina-home). Why?!
    "fmask=0137,dmask=0027"
  ];

  networking.useNetworkd = true;

  networking.useDHCP = false;
  networking.interfaces.enp88s0.useDHCP = true;
  networking.interfaces.enp89s0.useDHCP = true;

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

  services.fwupd.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # mdmonitor service is added by mdadm package and it will fail if we don't configure this.
  # (msmtp will resolve "root" to the intended recipient via aliases.)
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
