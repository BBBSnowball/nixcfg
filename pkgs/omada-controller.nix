# nix-build -E '(import <nixpkgs> {}).callPackage ./omada-controller.nix {}'
{ stdenv, fetchzip, openjdk, mongodb }:
stdenv.mkDerivation {
  pname = "omada-controller";
  version = "5.4.6";

  src = fetchzip {
    url = "https://static.tp-link.com/upload/software/2022/202207/20220729/Omada_SDN_Controller_v5.4.6_Linux_x64.tar.gz";
    hash = "sha256-PR+IFO0mnVZoVOZ+qt2Ro6VozDCoXH/3TmNx98+/7rQ=";
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

