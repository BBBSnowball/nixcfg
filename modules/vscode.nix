{ lib, pkgs, modules, ... }:
{
  imports = [ modules.allowUnfree ];
  nixpkgs.allowUnfreeByName = [ "vscode" ];

  environment.interactiveShellInit = let
    pioLibs = [
      "autoPatchelfHook"
      "udev"
      "zlib"
      "ncurses5"
      "expat"
      "mpfr"
      "libftdi"
      "libusb1"
      "hidapi"
      "libusb-compat-0_1"
      "xorg.libxcb"
      "freetype"
      "fontconfig"
      "python3"
      "stdenv.cc.cc.lib"
      "musl"
      "libkrb5"
      "lttng-ust"  # cpptools wants liblttng-ust.so.0 but this has liblttng-ust.so.1
      "lttng-ust_2_12.out"  # This one has liblttng-ust.so.0.
      # Java extension wants X11 libs.
      "xorg.libXext"
      "xorg.libX11"
      "xorg.libXrender"
      "xorg.libXi"
      "xorg.libXtst"
      "alsa-lib"
    ];
    pioLibs2 = [
      # remove meta.insecure attribute
      # (xtensa-esp32s3-elf-gdb needs libpython2.7.so.1.0)
      #"(python2.overrideAttrs(_:{meta={};}))"
    ];
    missingPioLibs = lib.lists.filter (name: !lib.attrsets.hasAttrByPath (lib.strings.splitString "." name) pkgs) pioLibs;
    pioLibsForNixShell =
      if missingPioLibs != []
      then builtins.abort "Missing packages for pioFix: ${builtins.toString missingPioLibs}"
      else lib.strings.concatMapStringsSep " " (name: "-p \"${name}\"") (pioLibs ++ pioLibs2);
  in ''
    # works for AVR and ESP32-C3
    alias pioFix='nix-shell ${pioLibsForNixShell} --run "patchShebangs /home/user/.platformio/packages/tool-avrdude/avrdude && autoPatchelf ~/.platformio/packages/ ~/.vscode/extensions"'
    alias fixPlatformIO=pioFix
  '';

  #users.users.user.packages = with pkgs; [ vscode ];  # We need MS C++ Extension for PlatformIO.
}
