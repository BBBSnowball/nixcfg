{ pkgs, ... }:
let
  openfpgaloaderRules = pkgs.stdenv.mkDerivation {
    pname = "openfpgaloader-udev";
    version = "0.8.0";
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/trabucayre/openFPGALoader/144e376d36268e05c973e4a599704b6a05c3b8db/99-openfpgaloader.rules";
      hash = "sha256-vrGmbdaP/HKTA82IvplQX0SYV+87eRwysZKL+0IjG9M=";
    };
    buildCommand = ''
      mkdir -p $out/etc/udev/rules.d
      cp $src $out/etc/udev/rules.d/99-openfpgaloader.rules
    '';
  };

  # We could replace this by platformio-core.udev but we currently need a rather new version for ESP32-S3.
  platformioRules = pkgs.stdenv.mkDerivation rec {
    pname = "platformio-udev";
    #version = "6.1.11";
    version = "5f8c15b96a0fe4d2f9dd490c34834f0fa17295fa";
    src = pkgs.fetchurl {
      #url = "https://github.com/platformio/platformio-core/raw/v${version}/platformio/assets/system/99-platformio-udev.rules";
      url = "https://raw.githubusercontent.com/platformio/platformio-core/${version}/platformio/assets/system/99-platformio-udev.rules";
      hash = "sha256-tbFYSqM6jomCETNul17th8Y0Ou5WXXdmLT33lMyj3g4=";
    };
    buildCommand = ''
      mkdir -p $out/etc/udev/rules.d
      substitute $src $out/etc/udev/rules.d/99-platformio-udev.rules \
        --replace 'MODE="0666"' 'MODE="664", GROUP="plugdev", TAG+="uaccess"'
    '';
  };
in
{
  users.users.user.packages = with pkgs; [
    vscode  # We need MS C++ Extension for PlatformIO.
    openocd gdb

    # set this in vscode:
    # "platformio-ide.disablePIOHomeStartup": true
    # "platformio-ide.useBuiltinPIOCore": false
    # "platformio-ide.useBuiltinPython": false
    #FIXME VS Code won't like either of them but it works fine when started from `nix-shell -p platformio-core`. It probably tries to guess some paths based on `which platformio`.
    platformio-core
    #platformio # fhsUserEnv with platformio-core --> VS Code refuses to use that
    #(python3.withPackages (p: [ pkgs.platformio-core ]))
  ];

  #environment.variables.PLATFORMIO_PENV_DIR = "${pkgs.platformio-core}";
 
  services.udev.extraRules = ''
    # ST-Link/V2
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3748", GROUP="dialout"
    # DAPLink
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", ATTR{idProduct}=="0204", GROUP="dialout"

    # Android Bootloader
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="d00d", GROUP="dialout"

    # Flipper Zero
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="5740", GROUP="dialout"

    # OpenUPS
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04d8", ATTR{idProduct}=="d004", GROUP="dialout"

    # fastboot (e.g. u-boot for bl808)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="4e40", GROUP="dialout"
  '';

  services.udev.packages = [ openfpgaloaderRules platformioRules ];

  users.groups.plugdev = {};
}
