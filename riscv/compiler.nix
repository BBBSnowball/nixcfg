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
  };
in rec {
  pkgs = p;
  inherit (p.pkgsBuildHost) gcc binutils binutils-unwrapped;
  gcc-riscv32imac = p1.runCommandLocal "gcc-riscv32imac-${gcc.version}" { } ''
    mkdir $out $out/bin
    for x in as c++ cc g++ gcc ld ld.bfd ; do
      ln -s ${gcc}/bin/riscv32-none-elf-$x $out/bin/riscv32imac-unknown-none-elf-$x
    done
    for x in addr2line ar c++filt elfedit gprof nm objcopy objdump ranlib readelf size strings strip ; do
      ln -s ${binutils-unwrapped}/bin/riscv32-none-elf-$x $out/bin/riscv32imac-unknown-none-elf-$x
    done
  '';
  openocd-nuclei = p1.pkgsBuildTarget.openocd.overrideAttrs (old: {
    pname = "openocd-nuclei";
    version = "0.10.0-14";
    src = p1.fetchFromGitHub {
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
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ (with p.pkgsBuildHost; [ tcl which gnum4 automake autoconf libtool ]);
    buildInputs = (old.buildInputs or []) ++ (with p.pkgsBuildBuild; [ libusb-compat-0_1 ]);
    preConfigure = ''
      ./bootstrap nosubmodule
    '';
    NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE + " -Wno-error=maybe-uninitialized -Wno-error=format";
    configureFlags = old.configureFlags ++ [ "--enable-usbprog" "--enable-rlink" "--enable-armjtagew" ];
  });

  # https://github.com/NixOS/nixpkgs/issues/68804
  #rustc-riscv = p1.pkgsCross.riscv32-embedded.buildPackages.rustc;
  rustc = p.buildPackages.rustc.overrideAttrs (old: { patches = (old.patches or []) ++ [ ./rustc-riscv.patch ]; });
  cargo = p1.cargo.override { inherit rustc; };

  shell = p.mkShell {
    depsBuildBuild = with p.pkgsBuildBuild; [ openssl pkg-config gcc rustc ];
    nativeBuildInputs = with p.pkgsBuildHost; [
      gcc
      #rustc
    ];
  };
}
