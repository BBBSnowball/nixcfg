let
  p1 = import <nixpkgs> { };
  p = import <nixpkgs> {
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

  # https://github.com/NixOS/nixpkgs/issues/68804
  #rustc-riscv = p1.pkgsCross.riscv32-embedded.buildPackages.rustc;
  rustc-riscv = p.buildPackages.rustc.overrideAttrs (old: { patches = (old.patches or []) ++ [ ./rustc-riscv.patch ]; });
  cargo-riscv = p1.cargo.override { rustc = rustc-riscv; };

  shell = p.mkShell {
    depsBuildBuild = with p.pkgsBuildBuild; [ openssl pkg-config gcc rustc ];
    nativeBuildInputs = with p.pkgsBuildHost; [
      gcc
      #rustc
    ];
  };
}
