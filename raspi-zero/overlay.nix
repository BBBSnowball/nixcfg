self: super: {
  raspiosLiteImage = self.fetchzip {
    name = "raspios-lite-2021-01-21";
    url = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-01-12/2021-01-11-raspios-buster-armhf-lite.zip";
    sha256 = "sha256-sE5eXZIog3e09i8W1M4qc6rvYMXoMxiEMuoooFhJq18=";
  };

  rpiboot = super.stdenv.mkDerivation {
    pname = "rpiboot";
    version = "2021-01-18-49a2a4";

    src = self.fetchFromGitHub {
      owner = "raspberrypi";
      repo = "usbboot";
      rev = "49a2a4f22eec755b8c0377b20a5ecbfee089643e";
      sha256 = "sha256-I6kCqlEd5cYTEwz9riQZvHDNbP638WFGntOUCjDVYDU=";
    };

    patchPhase = ''
      substituteInPlace main.c --replace 'rpiboot -d recovery' "rpiboot -d $out/share/rpiboot/recovery"
    '';

    buildInputs = [ self.libusb ];

    installPhase = ''
      mkdir -p $out/bin $out/share/rpiboot/{recovery,msd} $out/etc/udev/rules.d
      cp rpiboot $out/bin/
      cp recovery/{*.bin,*.sig,*.txt,*.conf,*.sh,rpi-eeprom-config} $out/share/rpiboot/recovery/
      cp msd/{*.elf,*.bin} $out/share/rpiboot/msd/
      cp debian/99-rpiboot.rules $out/etc/udev/rules.d/
    '';
  };

  rpireset = super.writeShellScriptBin "rpireset" ''
    # Reset pin of Pi Zero is connected to GPIO 54 (pin 11 of the connector) via a 1 kOhm resistor
    num=54
    [ -e /sys/class/gpio ] || ( echo "Kernel doesn't have CONFIG_GPIO_SYSFS!" >&2; exit 1 )
    [ -e /sys/class/gpio/gpio$num ] || echo $num >/sys/class/gpio/export
    [ "`cat /sys/class/gpio/gpio$num/direction`" == "out" ] || echo out >/sys/class/gpio/gpio$num/direction
    echo 0 >/sys/class/gpio/gpio$num/value
    sleep 0.2
    echo 1 >/sys/class/gpio/gpio$num/value
  '';

  # see <nixpkgs/nixos/modules/installer/cd-dvd/sd-image-aarch64.nix>
  # and https://dev.webonomic.nl/how-to-run-or-boot-raspbian-on-a-raspberry-pi-zero-without-an-sd-card
  rpibootfiles = let
    rpiConfig = import (self.nixpkgsPath + "/nixos") {
      system = self.stdenv.buildPlatform.system;
      configuration = ../hosts/raspi-zero/main.nix;
    };
  in super.runCommand "rpibootfiles" (with rpiConfig.pkgs; {
    inherit raspberrypifw;
    inherit (self) rpiboot;
    uboot = ubootRaspberryPiZero;
    configTxt = writeText "config.txt" ''
      #kernel=u-boot.bin
      kernel=zImage

      # U-Boot used to need this to work, regardless of whether UART is actually used or not.
      enable_uart=1

      # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
      # when attempting to show low-voltage or overtemperature warnings.
      avoid_warnings=1

      # enable OTG
      dtoverlay=dwc2
      # set initramfs
      initramfs initrd followkernel
    '';
    passthru.config = rpiConfig;
  }) ''
    mkdir $out
    cp -r $raspberrypifw/share/raspberrypi/boot/* $out/
    sed -ib "s/BOOT_UART=0/BOOT_UART=1/" $out/bootcode.bin
    rm $out/kernel*.img
    # use bootcode.bin from rpiboot because the other one doesn't work here (for whatever reason - closed source and whatnot...)
    rm -f $out/bootcode.bin
    cp $rpiboot/share/rpiboot/msd/bootcode.bin $out/bootcode.bin
    cp $uboot/u-boot.bin $out/
    cp $configTxt $out/config.txt
    #''${rpiConfig.config.boot.loader.generic-extlinux-compatible.populateCmd} -c ''${rpiConfig.config.system.build.toplevel} -d ./files/boot
    cp ${rpiConfig.config.system.build.kernel}/zImage $out/
    cp ${rpiConfig.config.system.build.initialRamdisk}/* $out/
    echo "${self.lib.strings.concatStringsSep " " rpiConfig.config.boot.kernelParams}" >$out/cmdline.txt
  '';
}
