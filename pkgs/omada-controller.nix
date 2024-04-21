# nix-build -E '(import <nixpkgs> {}).callPackage ./omada-controller.nix {}'
{ stdenv, fetchzip, openjdk, mongodb }:
stdenv.mkDerivation {
  pname = "omada-controller";
  version = "5.13.30.8";

  src = fetchzip {
    # https://www.tp-link.com/de/support/download/omada-software-controller/
    url = "https://static.tp-link.com/upload/software/2024/202402/20240227/Omada_SDN_Controller_v5.13.30.8_linux_x64.tar.gz";  # from the link above
    #url = "https://download.tplinkcloud.com/firmware/Omada_SDN_Controller_v5.13.23_linux_x64_20231228194009_1705039261727.tar.gz";  # from webinterface of controller
    hash = "sha256-hLSyZ8L4S3fpo5wI7qFWKDnaaJ1SIxK+kNV3dFx5mmU=";
    stripRoot = false;
  };

  buildInputs = [ openjdk mongodb ];

  patchPhase = ''
    rm -f readme.txt
    dir=("Omada_SDN_Controller"_*)
    mv "$dir"/* .
    rmdir "$dir"
  '';

  buildPhase = ''
    mkdir $out
    cp -r data properties lib $out/
    mkdir $out/bin
    cp bin/control.sh $out/bin/tpeap
    ln -s ${mongodb}/bin/mongod $out/bin/mongod
  '';

  meta.platforms = [ "x86_64-linux" ];
}

