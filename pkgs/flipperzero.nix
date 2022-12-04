# Usage: nix build .#flipperzero-firmware && ./result/bin/flipper-selfupdate ./result/f7-update-local/update.fuf
{ nixpkgs ? <nixpkgs>, lib ? (import nixpkgs {}).lib, system ? builtins.currentSystem, src ? null }:
let
  all = rec {
    targetArch = lib.systems.examples.armhf-embedded // {
      gcc.cpu = "cortex-m4";
      gcc.fpu = "fpv4-sp-d16";
      gcc.extraFlags = ["-mthumb" "-mlittle-endian"];
      libc = "newlib-nano";
    };
    pkgs = import nixpkgs {
      inherit system;
      crossSystem = targetArch;
      config.allowUnsupportedSystem = true;
    };
    stdenv = with pkgs; overrideCC pkgs.stdenv pkgsBuildHost.gcc10;
    mkShell = pkgs.mkShell.override { inherit stdenv; };

    # build scons with the correct Python version and newer sources because 4.1.0 is too old
    #scons = pp: pkgs.scons.override { pythonPackages = pp; } // { pythonModule = pp.python; };
    #(import "${nixpkgs}/pkgs/development/tools/build-managers/scons/default.nix" { inherit (pkgs.pkgsBuildHost) callPackage; python2 = null; python3 = pp.python; }).scons_latest
    scons = let
      version = "4.4.0";
      hash = "sha256-PUOyMDqSSBbqDhs0X/BMmz4ntT6t8PJgEvwMKbAZaF8=";
      src = pkgs.pkgsBuildHost.fetchurl {
        url = "mirror://sourceforge/project/scons/scons/${version}/SCons-${version}.tar.gz";
        inherit hash;
      };
    in pp: let
      pkg = pkgs.pkgsBuildHost.callPackage (import "${nixpkgs}/pkgs/development/tools/build-managers/scons/common.nix" {
        inherit version;
        sha256 = hash;
      }) { python = pp.python; };
      pkg2 = pkg.overrideAttrs (_: { inherit src; });
      # Tell python.withPackages that this has been built with the right interpreter (which buildPythonApplication doesn't do).
      pkg3 = pkg2 // { pythonModule = pp.python; };
    in pkg3;

    # pip2nix and pypi2nix seem to be broken so let's see how far we get without...
    # heatshrink2 is missing (but the build will use heatshrink cli instead) and some packages have the wrong version.
    pythonWithPkgs = pkgs.pkgsBuildHost.python3.withPackages (p: with p; [
      # This is what the documentation says they want.
      pyserial grpcio grpcio-tools pillow
      # This is what we seem to need in addition to that.
      (scons p) ansi colorlog
    ]);

    # clang-tools contains clang-format.
    hostDeps = with pkgs.pkgsBuildHost; [ clang-tools protobuf heatshrink pythonWithPkgs ];

    shell = mkShell {
      packages = hostDeps ++ (with pkgs.pkgsBuildHost; [ binutils dfu-util openocd ]);
    };
  };

  inherit (all) pkgs stdenv hostDeps;
in
  stdenv.mkDerivation rec {
    pname = "flipperzero-firmware";
    version = "0.72.1";  # change timestampOfCommit and tagOfCommit and PROTOBUF_VERSION to match this

    outputs = [ "out" "sdk" ];

    src = pkgs.fetchFromGitHub {
      owner = "flipperdevices";
      repo = "flipperzero-firmware";
      rev = version;
      fetchSubmodules = true;
      hash = "sha256-VTJ8Vobad+EUdQEtNRADwprHN9P8jUgSTdhP4rVDQBw=";
    };

    # git show -s --format=%ct
    timestampOfCommit = 1669990791;
    # git describe --always --long --all --dirty
    #tagOfCommit = "tags/0.72.1-0-g579e3b5f";
    # cd assets/protobuf && git fetch --tags && git describe --tags --abbrev=0
    PROTOBUF_VERSION = "0.14";

    nativeBuildInputs = hostDeps;

    patches = [
      ./flipperzero-fix-build.patch
      ./flipperzero-external-apps.patch
    ];

    # Don't build virtualenv, don't update git.
    FBT_NOENV = 1;
    FBT_NO_SYNC = 1;

    # Override some versions that the build would otherwise try to get from git.
    FBT_NO_GIT = 1;
    SOURCE_DATE_EPOCH = timestampOfCommit;
    WORKFLOW_BRANCH_OR_TAG = version;

    buildPhase = ''
      ./fbt fap_snake_game
      rm -rf build/f7-firmware-D/assets build/f7-firmware-D/.extapps
      cp -r . $sdk

      ./fbt fw_dist fap_dist copro_dist updater_package updater_minpackage
    '';

    #NOTE Use flipper-z-f7-update-local.tgz with qFlipper (well, doesn't work) or f7-update-local/update.fuf with selfupdate.py (see head of this file).
    #     The TAR and directory have the same data but the tools want them in different formats.
    installPhase = ''
      cp -r dist/f7-D $out
      cp build/core2_firmware.tgz $out/

      # replace ZIP files by actual directory because that's more useful in the Nix store
      for x in lib sdk ; do
        rm -f $out/flipper-z-f7-''${x}-local.zip
        cp -r build/f7-firmware-D/$x $out/$x
      done

      mkdir $out/bin
      for x in flash lint ob otp runfap selfupdate serial_cli slideshow storage ; do
        echo "#! ${pkgs.pkgsBuildHost.bash}/bin/bash" >$out/bin/flipper-$x
        echo "exec ${all.pythonWithPkgs}/bin/python $src/scripts/$x.py \"\$@\"" >>$out/bin/flipper-$x
        chmod +x $out/bin/flipper-$x
      done
    '';

    passthru = all;
  }
