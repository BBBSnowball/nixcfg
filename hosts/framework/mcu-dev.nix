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
in
{
  users.users.user.packages = with pkgs; [
    vscode  # We need MS C++ Extension for PlatformIO.
    openocd gdb
  ];
 
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
  '';

  services.udev.packages = [ openfpgaloaderRules ];

  users.groups.plugdev = {};
}
