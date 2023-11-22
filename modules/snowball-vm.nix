{ lib, modulesPath, modules, ... }:
{
  options.networking = with lib; {
    externalIp = mkOption {
      type = types.str;
      description = ''
        external IP of the server this VM is running on

        Open ports of this VM are forwarded via DNAT from this external IP.
      '';
    };
    upstreamIp = mkOption {
      type = types.str;
      description = ''
        internal IP of this VM towards the host

        Services should listen on this IP. This is usually the IP of the first network interface ("eth0").
      '';
    };
  };

  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    modules.common
    modules.snowball
    modules.snowball-headless
  ];
 
  config = {
    boot.loader.grub.enable = true;
    #boot.loader.grub.version = 2;
    boot.loader.grub.device = lib.mkDefault "/dev/vda";
  
    #headless = true;
    sound.enable = false;
    boot.vesa = false;
    boot.loader.grub.splashImage = null;
  
    #systemd.services."serial-getty@ttyS0".enable = true;
    boot.kernelParams = [ "console=ttyS0" ];
  
    #security.rngd.enable = false;  # removed in 21.09
  
    services.fstrim.enable = true;
  };
}
