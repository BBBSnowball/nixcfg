# see https://github.com/raspberrypi/pico-setup/blob/master/pico_setup.sh
{ system ? builtins.currentSystem, nixpkgs ? <nixpkgs>, ... }:
let
  p1 = import nixpkgs { inherit system; };
  p2 = import nixpkgs {
    inherit system;
    crossSystem = p1.lib.systems.examples.arm-embedded;
    config.allowUnsupportedSystem = true;
    overlays = [ fixUnnecessaryTargetDepsOverlay overlay ];
  };
  rppico-arch = p1.lib.systems.examples.arm-embedded // {
    #FIXME This probably must be outside of platform!
    platform = {
      gcc.cpu = "cortex-m0plus";
      gcc.extraFlags = ["-mthumb"];
    };
  };
  p = import nixpkgs {
    inherit system;
    crossSystem = rppico-arch;
    config.allowUnsupportedSystem = true;
    overlays = [ fixUnnecessaryTargetDepsOverlay fromP2Overlay overlay ];
  };
  lib = p1.lib;

  # Some packages are different if the target platform changes but they shouldn't be, in my opinion.
  # For example, Cython uses a GDB for the target but we won't ever use it for RISC-V code.
  fixUnnecessaryTargetDepsOverlay = self: super:
  if (with super.stdenv; buildPlatform.config == hostPlatform.config && hostPlatform.config != targetPlatform.config) then {
    # see https://nixos.wiki/wiki/Overlays#Python_Packages_Overlay
    python3 = super.python3.override {
      packageOverrides = self2: super2: {
        cython = super2.cython.override { inherit (self.pkgsBuildBuild) gdb; };
      };
    };
    python3Packages = self.python3.pkgs;

    thin-provisioning-tools = super.thin-provisioning-tools.override { inherit (self.pkgsBuildBuild) binutils; };
  } else {};

  fromP2Overlay = self: super:
    let pkgs = p2.pkgsBuildHost; in
    if (with super.stdenv; buildPlatform.config == pkgs.stdenv.buildPlatform.config && hostPlatform.config == pkgs.stdenv.hostPlatform.config && targetPlatform.config == pkgs.stdenv.targetPlatform.config) then { inherit (pkgs) gcc-unwrapped binutils-unwrapped; } else {};

  enablePicoprobe = true;
  openocd-rppico =
    { openocd, fetchFromGitHub, tcl, which, gnum4, automake, autoconf, libtool, libusb-compat-0_1, libusb, libgpiod }:
    openocd.overrideAttrs (old: {
      pname = "openocd-rppico";
      version = if enablePicoprobe then "2021-01-20-14c0d0" else "2021-01-08-7c9611";

      src = fetchFromGitHub {
        owner = "raspberrypi";
        repo = "openocd";
        rev = if enablePicoprobe
          then "14c0d0d330bd6b2cdc0605ee9a9256e5627a905e"  # branch picoprobe
          else "7c961195b91d921ccd5b71f178f9c4f53e7af921"; # branch rp2040
        sha256 = if enablePicoprobe then "sha256-o7shTToj6K37Xw+Crwif5WwB4GfPYIiMJ/o/9u3xrsE=" else "TODO";
        fetchSubmodules = true;
      };

      # patches in old.patches are already applied to that version
      patches = [ ];

      # autotools are required because we are building from git rather than source download; tcl is useful to avoid
      # bootstrapping when cross-compiling
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ tcl which gnum4 automake autoconf libtool ];

      # I think this should be in buildInputs but that would pull in Python with gdb for risc-v which is totally unnecessary here.
      buildInputs = (old.buildInputs or []) ++ [ libusb-compat-0_1 libusb ];

      preConfigure = ''
        ./bootstrap nosubmodule
      '';

      NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE ++ [ "-Wno-error=maybe-uninitialized" "-Wno-error=format" ];
      configureFlags = old.configureFlags ++ [
        "--enable-usbprog" "--enable-rlink" "--enable-armjtagew"
        "--enable-ftdi" "--enable-sysfsgpio" "--enable-bcm2835gpio"
      ] ++ (if enablePicoprobe then [ "--enable-picoprobe" ] else []);
    });

  picosdk = { stdenv, fetchFromGitHub, python3, pkg-config, cmake, gnumake, gcc, doxygen, graphviz, picoexamples, which, picotool, pioasm, elf2uf2 }: stdenv.mkDerivation {
    pname = "pico-sdk";
    version = "2021-01-23-0f3b79";

    src = fetchFromGitHub {
      owner = "raspberrypi";
      repo = "pico-sdk";
      rev = "0f3b7951167cf672afdcb34a58ddd0e363ae886f";  # master
      sha256 = "sha256-tOItVP54MooXDE6QsLDXVr4Kl1jw1tka2lo229A2Btc=";
      fetchSubmodules = true;
    };

    PICO_EXAMPLES_PATH = picoexamples.src;

    depsBuildBuild = [ doxygen graphviz gcc ];
    depsBuildBuildPropagated = [ which picotool pioasm elf2uf2 ];
    propagatedNativeBuildInputs = [ cmake gnumake pkg-config python3 ];

    patchPhase = ''
      rm -rf tools/{pioasm,elf2uf2}

      patchFindScript() {
        script=$1
        prefix=$2
        prefix2=$3
        elfname=$4
        target=$5

        for x in $depsBuildBuildPropagated ; do
          if [ -e $x/bin/$elfname ]; then
            pkg=$x
          fi
        done
        if [ -z "$pkg" ]; then
          echo "Error: Required tool not found: $elfname" >&2
        fi

      cat >$script <<EOF
      set(''${prefix}_BINARY_DIR $pkg/bin)
      set(''${prefix2}_EXECUTABLE $pkg/bin/$elfname)
      set(''${target}_TARGET $target)
      if (NOT ''${prefix2}_FOUND)
      set(''${prefix2}_FOUND 1)
      if(NOT TARGET $target)
        #add_custom_target( $target )
        add_executable($target IMPORTED)
      endif()
      set_property(TARGET $target PROPERTY IMPORTED_LOCATION $pkg/bin/$elfname)
      endif()
      EOF
      }

      patchFindScript tools/FindELF2UF2.cmake  ELF2UF2 ELF2UF2 elf2uf2 ELF2UF2
      patchFindScript tools/FindPicotool.cmake PICOTOOL PICOTOOL picotool Picotool
      patchFindScript tools/FindPioasm.cmake   PIOASM Pioasm pioasm Pioasm
    '';

    # omit default flags for cmake because we aren't actually building for Linux on rp2040
    configurePhase = ''cmake .'';

    installPhase = ''
      cp -a . $out
      mkdir $out/nix-support/
      echo "export PICO_SDK_PATH=$out" >$out/nix-support/setup-hook
    '';
  };

  pioasm = { stdenv, cmake, picosdk, pkg-config }: stdenv.mkDerivation {
    pname = "pioasm";
    version = picosdk.version;

    src = picosdk.src;

    nativeBuildInputs = [ cmake pkg-config ];

    preConfigure = ''cd tools/pioasm'';

    installPhase = ''
      mkdir $out $out/bin
      cp pioasm $out/bin/
      ln -s pioasm $out/bin/Pioasm
    '';
  };

  elf2uf2 = { stdenv, cmake, picosdk, pkg-config }: stdenv.mkDerivation {
    pname = "elf2uf2";
    version = picosdk.version;

    src = picosdk.src;

    nativeBuildInputs = [ cmake pkg-config ];

    preConfigure = ''cd tools/elf2uf2'';

    installPhase = ''
      mkdir $out $out/bin
      cp elf2uf2 $out/bin/
      ln -s elf2uf2 $out/bin/ELF2UF2
    '';
  };

  picotool = { stdenv, fetchFromGitHub, cmake, picosdk, libusb, pkg-config }: stdenv.mkDerivation {
    pname = "picotool";
    version = "2021-01-22-c15ac2";

    src = fetchFromGitHub {
      owner = "raspberrypi";
      repo = "picotool";
      rev = "c15ac281581318b7e2fb55ff613f71c7bde0a788";
      sha256 = "sha256-aXRKoHrfOXOze5yLNKFwfJoUGbT86Su4hVkzjnTRQbQ=";
    };

    nativeBuildInputs = [ cmake pkg-config ];
    buildInputs = [ libusb ];

    PICO_SDK_PATH = picosdk.src;

    installPhase = ''
      mkdir $out $out/bin
      cp picotool $out/bin/
    '';
  };

  picoprobe = { stdenv, fetchFromGitHub, picosdk }: stdenv.mkDerivation {
    pname = "picoprobe";
    version = "2021-01-20-f67a57";

    src = fetchFromGitHub {
      owner = "raspberrypi";
      repo = "picoprobe";
      rev = "f67a57d2baf6caad5e9dc4ba5049595f2ebeb512";
      sha256 = "sha256-guQgdH/YZUSjhOv50qo/KDM1dglC4ri8oGQbOPavi1c=";
    };

    buildInputs = [ picosdk ];

    configurePhase = ''cmake .'';

    installPhase = ''
      mkdir $out
      cp picoprobe.* $out/
    '';
  };

  picoexamples = { stdenv, fetchFromGitHub, picosdk }: stdenv.mkDerivation {
    pname = "picoexamples";
    version = "2021-01-26-58f46b";

    src = fetchFromGitHub {
      owner = "raspberrypi";
      repo = "pico-examples";
      rev = "58f46b252629da33069bb5d04625c223b5262649";  # master
      sha256 = "sha256-/lh5y38WxvVhg5xcBtyYS9mcx9Xs1AbAChHiDN9FXuk=";
    };

    buildInputs = [ picosdk ];

    configurePhase = ''cmake .'';

    installPhase = ''
      mkdir $out
      cp -r . $out/
    '';
  };

  picoplayground = { stdenv, fetchFromGitHub, picosdk, picoextras }: stdenv.mkDerivation {
    pname = "picoplayground";
    version = "2021-01-28-6288b0";

    src = fetchFromGitHub {
      owner = "raspberrypi";
      repo = "pico-playground";
      rev = "6288b02e9a35e9e4e9bf47844c6f4f34ae8906c6";  # master
      sha256 = "sha256-BMHvXfONhnm91h5XsnOVAaiUBCUxtNjs4zD9s7yhEeY=";
    };

    buildInputs = [ picosdk picoextras ];

    configurePhase = ''cmake .'';

    installPhase = ''
      cp -r . $out
    '';
  };

  picoextras = { stdenv, fetchFromGitHub, picosdk }: stdenv.mkDerivation {
    pname = "picoextras";
    version = "2021-01-28-f5c7be";

    src = fetchFromGitHub {
      owner = "raspberrypi";
      repo = "pico-extras";
      rev = "f5c7be9a86e3131cd13d2cc3493b84b23676f8c4";  # master
      sha256 = "sha256-MeoDMmGgVzbwP+Q2KH6YthZADcXAAf9GfcgVJAKeZVs=";
      fetchSubmodules = true;
    };

    buildInputs = [ picosdk ];

    patchPhase = ''
      echo "void __sync_synchronize(void) {}" >test/sample_conversion_test/sync_dummy.c
      sed -i 's/ sample_conversion_test.cpp)/ sample_conversion_test.cpp sync_dummy.c)/' test/sample_conversion_test/CMakeLists.txt
    '';

    configurePhase = ''cmake .'';

    installPhase = ''
      cp -r . $out
      mkdir $out/nix-support/
      echo "export PICO_EXTRAS_PATH=$out" >$out/nix-support/setup-hook
    '';
  };

  overlay = self: super: {
    openocd-rppico = self.callPackage openocd-rppico {};
    picosdk = self.callPackage picosdk {};
    pioasm = self.callPackage pioasm {};
    elf2uf2 = self.callPackage elf2uf2 {};
    picotool = self.callPackage picotool {};
    picoprobe = self.callPackage picoprobe {};
    picoexamples = self.callPackage picoexamples {};
    picoplayground = self.callPackage picoplayground {};
    picoextras = self.callPackage picoextras {};
  };
in rec {
  pkgs = p;
  inherit (p.pkgsBuildHost) gcc gcc-unwrapped binutils binutils-unwrapped openocd-rppico gdb picotool pioasm elf2uf2;
  inherit (p.pkgsHostHost) picoprobe picosdk picoexamples picoplayground picoextras;

  shell = p.mkShell {
    depsBuildBuild = with p.pkgsBuildBuild; [
      pkg-config gcc
    ];
    nativeBuildInputs = with p.pkgsBuildHost; [
      gcc binutils binutils-unwrapped openocd-rppico gdb picotool
    ];
    buildInputs = with p.pkgsHostHost; [ picosdk picoprobe picoextras ];
  };
}
