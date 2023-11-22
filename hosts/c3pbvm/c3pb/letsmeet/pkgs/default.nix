{ pkgs ? import <nixpkgs> {}, nodejs ? pkgs.nodejs, lib ? pkgs.lib }:
rec {
  #default = import ./. { inherit pkgs; };
  #inherit (pkgs.nodePackages.override { nodejs = default.nodejs; }) node2nix;
  inherit (pkgs.nodePackages.override { inherit nodejs; }) node2nix;
  inherit (pkgs) yarn2nix;

  version = "3.5.6";
  edumeetSrc = pkgs.fetchFromGitHub {
    owner = "edumeet";
    repo  = "edumeet";
    rev = version;
    hash = "sha256-EUoMphniCcK5IMsArF3JQ9iyrqYPqbtmNT/f6uXiZEg=";
  };
  src = edumeetSrc;

  go = name: extra: pkgs.mkYarnPackage (rec {
    inherit name;
    src = "${edumeetSrc}/${name}";
    #packageJSON = "${src}/package.json";
    #yarnLock = "${src}/yarn.lock";
    yarnNix = "${./.}/yarn-${name}.nix";
  } // extra);

  app = go "app" {};

  mediasoupDepsSrcs = {
    "abseil-cpp-20211102.0.tar.gz" = pkgs.fetchurl {
      url = "https://github.com/abseil/abseil-cpp/archive/20211102.0.tar.gz";
      sha256 = "dcf71b9cba8dc0ca9940c4b316a0c796be8fab42b070bb6b7cab62b48f0e66c4";
    };
    "abseil-cpp_20211102.0-2_patch.zip" = pkgs.fetchurl {
      url = "https://wrapdb.mesonbuild.com/v2/abseil-cpp_20211102.0-2/get_patch";
      sha256 = "9463930367b0db984435350c7d7614e400faa8811a7e9a2def5a63ff39fdb325";
    };
    "Catch2-2.13.7.zip" = pkgs.fetchurl {
      url = "https://github.com/catchorg/Catch2/archive/v2.13.7.zip";
      sha256 = "3f3ccd90ad3a8fbb1beeb15e6db440ccdcbebe378dfd125d07a1f9a587a927e9";
    };
    "catch2_2.13.7-1_patch.zip" = pkgs.fetchurl {
      url = "https://wrapdb.mesonbuild.com/v2/catch2_2.13.7-1/get_patch";
      sha256 = "2f7369645d747e5bd866317ac1dd4c3d04dc97d3aad4fc6b864bdf75d3b57158";
    };
    "libsrtp-2.4.2.zip" = pkgs.fetchurl {
      url = "https://github.com/cisco/libsrtp/archive/refs/tags/v2.4.2.zip";
      sha256 = "35b1ae7a6256224feb058f1feb42170537a44896340f80e77b49cc59af686a82";
    };
    "libuv-v1.44.1.tar.gz" = pkgs.fetchurl {
      url = "https://dist.libuv.org/dist/v1.44.1/libuv-v1.44.1.tar.gz";
      sha256 = "9d37b63430fe3b92a9386b949bebd8f0b4784a39a16964c82c9566247a76f64a";
    };
    "libuv_1.44.1-1_patch.zip" = pkgs.fetchurl {
      url = "https://wrapdb.mesonbuild.com/v2/libuv_1.44.1-1/get_patch";
      sha256 = "8a105158cdabca2a54f1c7cc4c2f814c159271e10dc5e37ed1a08f13cfd67ff7";
    };
    "nlohmann_json-3.10.5.zip" = pkgs.fetchurl {
      url = "https://github.com/nlohmann/json/releases/download/v3.10.5/include.zip";
      sha256 = "b94997df68856753b72f0d7a3703b7d484d4745c567f3584ef97c96c25a5798e";
    };
    "openssl-3.0.2.tar.gz" = pkgs.fetchurl {
      url = "https://www.openssl.org/source/openssl-3.0.2.tar.gz";
      sha256 = "98e91ccead4d4756ae3c9cde5e09191a8e586d9f4d50838e7ec09d6411dfdb63";
    };
    "openssl_3.0.2-1_patch.zip" = pkgs.fetchurl {
      url = "https://wrapdb.mesonbuild.com/v2/openssl_3.0.2-1/get_patch";
      sha256 = "762ab4ea94d02178d6a1d3eb63409c2c4d61315d358391cdac62df15211174d4";
    };
    "4e06feb01cadcd127d119486b98a4bd3d64aa1e7.zip" = pkgs.fetchurl {
      url = "https://github.com/sctplab/usrsctp/archive/4e06feb01cadcd127d119486b98a4bd3d64aa1e7.zip";
      sha256 = "15f7844c4c4ca93228ae0fe844182c72edd1d809b461cb97b1bb687a804dd4fc";
    };
    "wingetopt-1.00.zip" = pkgs.fetchurl {
      url = "https://github.com/alex85k/wingetopt/archive/v1.00.zip";
      sha256 = "4454ca03a59702a4ca4d1488ca8fa6168b0c8d77dc739a6fe2825c3dd8609d87";
    };
  };
  mediasoupDeps = pkgs.runCommand "mediasoup-deps" {} ''
    mkdir $out
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: "ln -s ${src} $out/${name}") mediasoupDepsSrcs)}
  '';

  server = go "server" {
    pkgConfig.mediasoup = {
      nativeBuildInputs = with pkgs; [ python3 meson ninja which ];
      postInstall = ''
        # The Makefile wants to install them via pip but we don't want that.
        mkdir -p worker/out/pip/bin
        for tool in meson ninja ; do
          ln -s `which $tool` worker/out/pip/bin/$tool
        done

        mkdir -p worker/subprojects/packagecache
        cp ${mediasoupDeps}/* worker/subprojects/packagecache/

        echo "echo $NIX_BUILD_CORES" >worker/scripts/cpu_cores.sh

        make -C worker CORES=$NIX_BUILD_CORES

        rm -rf worker/out/pip
      '';
    };

    pkgConfig.bcrypt = {
      nativeBuildInputs = with pkgs; [ nodejs.pkgs.node-pre-gyp python3 ];
      postInstall = ''
        export CPPFLAGS="-I${nodejs}/include/node"
        node-pre-gyp install --prefer-offline --build-from-source --nodedir=${nodejs}/include/node
      '';
    };
  };
}
