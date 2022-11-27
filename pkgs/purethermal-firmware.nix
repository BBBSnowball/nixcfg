{ nixpkgs ? <nixpkgs>, lib ? (import nixpkgs {}).lib, system ? builtins.currentSystem, src ? null }:
rec {
  purethermal-arch = lib.systems.examples.armhf-embedded // {
    gcc.cpu = "cortex-m4";
    gcc.fpu = "fpv4-sp-d16";
    gcc.extraFlags = ["-mthumb"];
  };
  pkgs = import nixpkgs {
    inherit system;
    crossSystem = purethermal-arch;
    config.allowUnsupportedSystem = true;
  };

  shell = pkgs.pkgsBuildHost.mkShell {
    packages = (with pkgs.pkgsBuildHost; [ gcc binutils dfu-util ])
      ++ (with pkgs; [ newlib ]);
  };

  installScriptTemplate = ''
    #!/bin/sh
    if [ "$1" != "--do-it" ] ; then
      echo "This will flash the firmware without further questions and without checking whether the target STM really is a PureThermal board!" >&2
      echo "Usage: $0 --do-it [further args for dfu-util]" >&2
      exit 1
    fi
    shift
    exec @dfuutil@ -a 0 -D @out@/share/firmware.bin -s 0x08000000:leave "$@"
  '';

  firmware-unapplied = { stdenv, fetchFromGitHub, dfu-util, which }:
  stdenv.mkDerivation {
    pname = "purethermal1-firmware";
    version = "1.3.0";

    src = if src != null then src else fetchFromGitHub {
      owner = "groupgets";
      repo = "purethermal1-firmware";
      rev = "1.3.0";
      hash = "sha256-ImWDv4y2JOVXHPQeGLkN4WNEwKg88MP482LlR1bmgOA=";
    };

    nativeBuildInputs = [ dfu-util which ];

    versionHeaderTemplate = ''
      #ifndef VERSION_H
      #define VERSION_H
      #define BUILD_GIT_SHA "@version@"
      #define BUILD_DATE "1970-01-01 00:00:00"
      #endif
    '';

    inherit installScriptTemplate;
    passAsFile = [ "versionHeaderTemplate" "installScriptTemplate" ];

    buildPhase = ''
      mkdir .git; touch .git/HEAD .git/index
      substitute $versionHeaderTemplatePath Inc/version.h --subst-var version

      make SYSTEM=arm-none-eabihf-
    '';

    installPhase = ''
      mkdir -p $out/bin $out/share
      for x in out map list hex bin ; do
        cp main.$x $out/share/firmware.$x
      done
      mv $out/share/firmware.out $out/share/firmware.elf
      substitute $installScriptTemplatePath $out/bin/flash-purethermal1-firmware --subst-var out --subst-var-by dfuutil $(which dfu-util)
      chmod +x $out/bin/flash-purethermal1-firmware
    '';
  };
  firmware = pkgs.callPackage firmware-unapplied {};

  firmware-original-unapplied = { stdenv, dfu-util, which }:
  stdenv.mkDerivation {
    name = "purethermal1-firmware-original";

    nativeBuildInputs = [ dfu-util which ];

    inherit installScriptTemplate;
    passAsFile = [ "installScriptTemplate" ];

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/bin $out/share
      ln -s ${./2022-10-08-PureThermal3-stock-firmware-0-flash-page01.bin} $out/share/firmware.bin
      substitute $installScriptTemplatePath $out/bin/flash-purethermal1-firmware \
        --subst-var out --subst-var-by dfuutil $(which dfu-util)
      chmod +x $out/bin/flash-purethermal1-firmware
    '';
  };
  firmware-original = pkgs.callPackage firmware-original-unapplied {};
}

