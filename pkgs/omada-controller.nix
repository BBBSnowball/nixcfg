# nix-build -E '(import <nixpkgs> {}).callPackage ./omada-controller.nix {}'
{ stdenv, fetchzip, openjdk, mongodb }:
stdenv.mkDerivation {
  pname = "omada-controller";
  version = "5.13.22";

  src = fetchzip {
    # https://www.tp-link.com/de/support/download/omada-software-controller/
    url = "https://static.tp-link.com/upload/software/2023/202312/20231201/Omada_SDN_Controller_v5.13.22_Linux_x64.tar.gz";
    hash = "sha256-v/lDQcl9bkJBIMh+8y9is9KXp/AoVVeJ2j40YbKlv2Y=";
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

