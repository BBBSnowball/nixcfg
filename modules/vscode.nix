{ lib, pkgs, ... }:
{
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
  ];

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
      "python2"
      "stdenv.cc.cc.lib"
      "musl"
      "libkrb5"
      "lttng-ust"  # cpptools wants liblttng-ust.so.0 but this has liblttng-ust.so.1
    ];
    missingPioLibs = lib.lists.filter (name: !lib.attrsets.hasAttrByPath (lib.strings.splitString "." name) pkgs) pioLibs;
    pioLibsForNixShell =
      if missingPioLibs != []
      then builtins.abort "Missing packages for pioFix: ${builtins.toString missingPioLibs}"
      else lib.strings.concatMapStringsSep " " (name: "-p ${name}") pioLibs;
  in ''
    # works for AVR and ESP32-C3
    alias pioFix='nix-shell ${pioLibsForNixShell} --run "patchShebangs /home/user/.platformio/packages/tool-avrdude/avrdude && autoPatchelf ~/.platformio/packages/ ~/.vscode/extensions"'
    alias fixPlatformIO=pioFix
  '';

  #users.users.user.packages = with pkgs; [ vscode ];  # We need MS C++ Extension for PlatformIO.
}
