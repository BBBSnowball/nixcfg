{ lib, pkgs, lanzaboote, ... }:
{
  imports = [
    # infinite recursion, so add it in main.nix instead
    #lanzaboote.nixosModules.lanzaboote
  ];

  environment.systemPackages = with pkgs; [
    sbctl
    tpm2-tools
  ];

  # Lanzaboote currently replaces the systemd-boot module.
  # This setting is usually set to true in configuration.nix
  # generated at installation time. So we force it to false
  # for now.
  # see https://github.com/nix-community/lanzaboote/blob/master/docs/QUICK_START.md#configuring-nixos-with-flakes
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  environment.etc."secureboot/keys".source = "/etc/nixos/secret_local/secureboot/keys";

  # might help according to Arch wiki but depends on which TPM we have
  # (Microsoft Pluton, in our case)
  boot.initrd.availableKernelModules = [ "tpm_crb" ];

  # use systemd for initrd, so systemd-cryptenroll can be used
  boot.initrd.systemd.enable = true;
}

# https://github.com/nix-community/lanzaboote/blob/master/docs/QUICK_START.md
# sbctl create-keys
# mv /etc/secureboot/keys /etc/nixos/secret_local/secureboot/keys
# ln -s /etc/nixos/secret_local/secureboot/keys /etc/secureboot/keys
# nixos-rebuild ..
# sbctl verify
# reboot, remove existing secure boot keys to enter setup mode, enable secure boot
#FIXME What are the option roms? Can we avoid them?
# sbctl enroll-keys --microsoft
# reboot
# bootctl status
# systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=no /dev/ssd/root
