{ system ? builtins.system, nixpkgs ? <nixpkgs>, ... }:
let
  p1 = import nixpkgs { inherit system; };
  p = import nixpkgs {
    inherit system;
    crossSystem = p1.lib.systems.examples.riscv32-embedded // {
      # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md
      rustc.config = "riscv32imac-unknown-none-elf";
    };
    config.allowUnsupportedSystem = true;
    overlays = [ overlay ];
  };
  openocd-nuclei =
    { openocd, fetchFromGitHub, tcl, which, gnum4, automake, autoconf, libtool, libusb-compat-0_1 }:
    openocd.overrideAttrs (old: {
      pname = "openocd-nuclei";
      version = "0.10.0-14";

      src = fetchFromGitHub {
        owner = "riscv-mcu";
        repo = "riscv-openocd";
        rev = "nuclei-0.10.0-14"; #"9e6a7a2e5320cdaeeafcc79debedfd216f443f19"
        sha256 = "sha256-dNEwrsIlxlWgm7mH16XBKoUVB78pNcJ58i+VjY33wXE=";
        fetchSubmodules = true;
      };

      # patches in old.patches are already applied to that version
      patches = [];

      # autotools are required because we are building from git rather than source download; tcl is useful to avoid
      # bootstrapping when cross-compiling
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ tcl which gnum4 automake autoconf libtool ];

      # I think this should be in buildInputs but that would pull in Python with gdb for risc-v which is totally unnecessary here.
      #buildInputs = (old.buildInputs or []) ++ [ p1.pkgsBuildBuild.libusb-compat-0_1 ];
      buildInputs = (old.buildInputs or []) ++ [ libusb-compat-0_1 ];

      preConfigure = ''
        ./bootstrap nosubmodule
      '';

      NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE + " -Wno-error=maybe-uninitialized -Wno-error=format";
      configureFlags = old.configureFlags ++ [ "--enable-usbprog" "--enable-rlink" "--enable-armjtagew" ];
    });
  overlay = self: super: {
    openocd-nuclei = self.callPackage openocd-nuclei {};

    # see https://nixos.wiki/wiki/Overlays#Python_Packages_Overlay
    python3 = super.python3.override {
      packageOverrides = self2: super2: {
        cython = super2.cython.overrideAttrs (old: {
          # We should not depend on GDB for the target because Cython will only be used on the host.
          buildInputs = [ self.glibcLocales ];
          depsHostHost = [ self.gdb ];
        });
      };
    };
  };
in rec {
  pkgs = p;
  inherit (p.pkgsBuildHost) gcc binutils binutils-unwrapped openocd-nuclei;
  gcc-riscv32imac = p1.runCommandLocal "gcc-riscv32imac-${gcc.version}" { } ''
    mkdir $out $out/bin
    for x in as c++ cc g++ gcc ld ld.bfd ; do
      ln -s ${gcc}/bin/riscv32-none-elf-$x $out/bin/riscv32imac-unknown-none-elf-$x
    done
    for x in addr2line ar c++filt elfedit gprof nm objcopy objdump ranlib readelf size strings strip ; do
      ln -s ${binutils-unwrapped}/bin/riscv32-none-elf-$x $out/bin/riscv32imac-unknown-none-elf-$x
    done
  '';

  # https://github.com/NixOS/nixpkgs/issues/68804
  #rustc-riscv = p1.pkgsCross.riscv32-embedded.buildPackages.rustc;
  rustc = p.buildPackages.rustc.overrideAttrs (old: { patches = (old.patches or []) ++ [ ./rustc-riscv.patch ]; });
  cargo = p1.cargo.override { inherit rustc; };

  shell = p.mkShell {
    depsBuildBuild = with p.pkgsBuildBuild; [ openssl pkg-config gcc rustc openocd-nuclei ];
    nativeBuildInputs = with p.pkgsBuildHost; [
      gcc
      #rustc
    ];
  };
}
