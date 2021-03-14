let
  version = "6.25.002";
  overlay = self: super: {
    greenpakDesignerSrc = self.fetchurl {
      # https://support.dialog-semiconductor.com/downloads/GP_Designer_v6.25.002_WIN_Setup.zip
      # https://support.dialog-semiconductor.com/downloads/GP_Designer_v6.25.002_WIN64_Setup.zip
      # https://support.dialog-semiconductor.com/downloads/GP_Designer_v6.25.002_MAC_Setup.zip
      # https://support.dialog-semiconductor.com/downloads/GP_Designer_v6.25.002_Ubuntu-18.04_amd64_Setup.deb
      # https://support.dialog-semiconductor.com/downloads/GP_Designer_v6.25.002_Debian-testing_i386_Setup.deb
      # https://support.dialog-semiconductor.com/downloads/GP_Designer_v6.25.002_Debian-testing_amd64_Setup.deb
      url = "https://support.dialog-semiconductor.com/downloads/GP_Designer_v${version}_Debian-testing_amd64_Setup.deb";
      sha256 = "sha256-P+87XF5snXmIB4jpI0KCvGKqzYSJ937b+nN/f3Hr9p8=";
    };
    greenpakSpiceCodemodel = self.runCommand "extract-greenpak-codemodel" {
      src = self.greenpakDesignerSrc;
      ar = self.binutils-unwrapped;
      inherit (self) gnutar lzma;
    } ''
      $ar/bin/ar x $src
      export PATH=$PATH:$lzma/bin
      tar -xf data.tar.*
      mkdir -p $out/lib
      cp ./usr/local/greenpak-designer/libexec/codemodels/slgdev.cm $out/lib/
    '';
    blt = self.stdenv.mkDerivation {
      pname = "blt";
      version = "2.4";
      src = self.fetchzip {
        #url = "ftp://www.sourceforge.net/projects/blt/files/BLT2.4z.tar.gz";
        #url = "https://downloads.sourceforge.net/project/blt/BLT/BLT%202.4z/BLT2.4z.tar.gz";
        url = "mirror://sourceforge/blt/BLT/BLT%202.4z/BLT2.4z.tar.gz";
        sha256 = "sha256-noUrS37FhWket5KkXunQ17j6tD7aSCjdOmJ91fMTsKI=";
      };
      patches = [ ./blt-with-tcl86.patch ];
      #buildInputs = with self; [ tcl tk tk.dev xorg.libX11.dev xorg.libX11 xorg.libXt ];
      buildInputs = with self; [ tcl tk tk.dev xorg.libX11 xorg.libXt ];
      configureFlags = [ "--with-tcl=${self.tcl}" "--with-tk=${self.tk}" "--with-tkincls=${self.tk.dev}/include" ];
      preConfigure = ''
        #mkdir tk-config
        #substitute ${self.tk}/lib/tkConfig.sh tk-config/tkConfig.sh --replace ${self.tk}/include ${self.tk.dev}/include
        #configureFlagsArray=( "--with-tcl=${self.tcl}" "--with-tk=`pwd`/tk-config" )
        configureFlagsArray=( "--exec-prefix=$out" )
      '';
      #preBuild = ''
      #  makeFlags+=(libdir=$out/lib)
      #  substituteInPlace src/Makefile        --replace "libdir = 	${self.tcl}/lib" "libdir = 	$out/lib"
      #  substituteInPlace src/shared/Makefile --replace "libdir =	${self.tcl}/lib" "libdir =	$out/lib"
      #'';
    };
    ngspiceFull = self.ngspice.overrideAttrs (old: {
      admsSrc = self.fetchzip {
        url = "mirror://sourceforge/ngspice/ng-spice-rework/old-releases/32/ng_adms_va.tar.gz";
        sha256 = "sha256-j/FktTUkWZr+jM5W7vC3BgAugluHGqHEefO0/+lELPI=";
      };
      prePatch = ''
        cp -r $admsSrc/* src/
        chmod -R u+w src
      '';

      enableParallelBuilding = true;

      buildInputs = with self; old.buildInputs ++ [ adms tcl blt ];
      nativeBuildInputs = with self.pkgsBuildHost; old.nativeBuildInputs ++ [ autoconf automake libtool ];

      configureFlags = old.configureFlags ++ [ "--enable-adms" "--enable-pss" "--with-tcl=${self.tcl}" ];
      TCLLIBPATH = with self; [ "${tk}/lib" "${blt}/lib" ];
      preConfigure = ''
        export TCLLIBPATH

        ./autogen.sh --adms

        #FIXME ugly!
        export CFLAGS="-I${self.blt}/include -I${self.tcl}/include -I${self.tk}/include"
        export LDFLAGS="-L${self.blt}/lib -L${self.tcl}/lib -L${self.tk}/lib -lBLT24 -ltk -ltcl"
      '';
    });
    ngspiceGreenpak = let
      ngspice-x64 = if false
        # cross compile
        then self.crossPkgs.x86_64-linux.ngspice
        # hope that Hydra has it
        else (import self.path { localSystem = "x86_64-linux"; }).ngspice;
      bin = if self.stdenv.hostPlatform.system == "x86_64-linux"
        then [ "${self.ngspice}/bin/ngspice" self.ngspice ]
        else [ "${self.qemu}/bin/qemu-x86_64 ${ngspice-x64}/bin/ngspice" ngspice-x64 ];
    in self.writeShellScriptBin "ngspice" ''
      export NGSPICE_PREFIX=${builtins.elemAt bin 1}
      export GREENPAK_SLGDEV_PREFIX=${self.greenpakSpiceCodemodel}
      exec ${builtins.elemAt bin 0} "$@"
    '';
    greenpakShell = self.mkShell { buildInputs = with self; [ ngspiceGreenpak ]; };
  };
in
{ pkgs ? import <nixpkgs> {} }:
let self = pkgs // overlay self pkgs; in
self // { inherit version overlay; }

