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

    buildInputs = [ self.libusb ];

    installPhase = ''
      mkdir -p $out/bin $out/share/rpiboot/{recovery,msd} $out/etc/udev/rules.d
      cp rpiboot $out/bin/
      cp recovery/{*.bin,*.sig,*.txt,*.conf,*.sh,rpi-eeprom-config} $out/share/rpiboot/recovery/
      cp msd/{*.elf,*.bin} $out/share/rpiboot/msd/
      cp debian/99-rpiboot.rules $out/etc/udev/rules.d/
    '';
  };
}
