{ nixpkgs ? <nixpkgs>, lib ? (import nixpkgs {}).lib, system ? builtins.currentSystem, src ? null }:
let
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

  firmware-unapplied-fn = { src, ... }@args: { stdenv, fetchFromGitHub, dfu-util, which, python3 }:
  let useEnterDfuScript = args.useEnterDfuScript or false; in
  stdenv.mkDerivation ({
    pname = "purethermal1-firmware";

    src = src { inherit fetchFromGitHub; };

    nativeBuildInputs = [ dfu-util which ];
    # Python doesn't seem to like this ARM architecture - even for pkgsHostHost. Well, ok, let's not
    # replace the she-bang for enter-dfu.py. It should be fine because it calls nix-shell.
    #depsHostHost = lib.optional useEnterDfuScript [ (python3.withPackages(p:[p.pyusb])) ];

    versionHeaderTemplate = ''
      #ifndef VERSION_H
      #define VERSION_H
      #define BUILD_GIT_SHA "@version@"
      #define BUILD_DATE "1970-01-01 00:00:00"
      #endif
    '';

    inherit useEnterDfuScript installScriptTemplate;
    passAsFile = [ "versionHeaderTemplate" "installScriptTemplate" ];

    OPTIONS = "";

    buildPhase = ''
      mkdir .git; touch .git/HEAD .git/index
      substitute $versionHeaderTemplatePath Inc/version.h --subst-var version

      make SYSTEM=arm-none-eabihf- OPTIONS="$OPTIONS"
    '';

    installPhase = ''
      mkdir -p $out/bin $out/share
      for x in out map list hex bin ; do
        cp main.$x $out/share/firmware.$x
      done
      mv $out/share/firmware.out $out/share/firmware.elf

      if [ "$useEnterDfuScript" == 1 ]; then
        cp scripts/enter-dfu.py $out/share/
        substitute $installScriptTemplatePath $out/bin/flash-purethermal1-firmware --subst-var out \
          --subst-var-by dfuutil "$out/share/enter-dfu.py $(which dfu-util)"
      else
        substitute $installScriptTemplatePath $out/bin/flash-purethermal1-firmware --subst-var out --subst-var-by dfuutil $(which dfu-util)
      fi
      chmod +x $out/bin/flash-purethermal1-firmware
    '';
  } // removeAttrs args ["src"]);

  firmware-original-bin-unapplied = { stdenv, dfu-util, which }:
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
in rec {
  inherit purethermal-arch pkgs shell;

  inherit firmware-original-bin-unapplied;
  firmware-original-bin = pkgs.callPackage firmware-original-bin-unapplied {};

  firmware-upstream-unapplied = firmware-unapplied-fn {
    pname = "purethermal1-firmware";
    version = "1.3.0";

    src = { fetchFromGitHub }: fetchFromGitHub {
      owner = "groupgets";
      repo = "purethermal1-firmware";
      rev = "1.3.0";
      hash = "sha256-ImWDv4y2JOVXHPQeGLkN4WNEwKg88MP482LlR1bmgOA=";
    };
  };
  firmware-upstream = pkgs.callPackage firmware-upstream-unapplied {};

  firmware-unapplied = firmware-unapplied-fn {
    name = "purethermal1-firmware";
    version = "1.3.0";

    src = { fetchFromGitHub }: if src != null then src else fetchFromGitHub {
      owner = "BBBSnowball";
      repo = "purethermal1-firmware";
      rev = "6282234a98d974b7b16bc958bca9f7296a2d52a4";
      hash = "sha256-Mg8s48lMmS3tuJ6U6z3mbHgCwYLKJ/IQE5dWgsmFL2U=";
    };

    OPTIONS = "MLX90614 MLX90614_OVERLAY OVERLAY_DEFAULT_ON";

    useEnterDfuScript = true;
  };
  firmware = pkgs.callPackage firmware-unapplied {};
}
