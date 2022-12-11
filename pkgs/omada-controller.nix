# nix-build -E '(import <nixpkgs> {}).callPackage ./omada-controller.nix {}'
{ stdenv, fetchzip, openjdk, mongodb }:
stdenv.mkDerivation {
  pname = "omada-controller";
  version = "5.7.4";

  src = fetchzip {
    # https://www.tp-link.com/de/support/download/omada-software-controller/
    url = "https://static.tp-link.com/upload/software/2022/202211/20221121/Omada_SDN_Controller_v5.7.4_Linux_x64.tar.gz";
    hash = "sha256-SiBy2WxBvGi/KsXL7/yBa4MWb6rsqjOT1sGvWylUbHE=";
  };

  buildInputs = [ openjdk mongodb ];

  buildPhase = ''
    mkdir $out
    cp -r data properties lib $out/
    mkdir $out/bin
    cp bin/control.sh $out/bin/tpeap
    ln -s ${mongodb}/bin/mongod $out/bin/mongod
  '';

  meta.platforms = [ "x86_64-linux" ];
}

