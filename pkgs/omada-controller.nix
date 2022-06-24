# nix-build -E '(import <nixpkgs> {}).callPackage ./omada-controller.nix {}'
{ stdenv, fetchzip, openjdk, mongodb }:
stdenv.mkDerivation {
  pname = "omada-controller";
  version = "5.3.1";

  #src = requireFile {
  #  name = "Omada_SDN_Controller_v5.3.1_Linux_x64.tar.gz";
  #  url = "https://www.tp-link.com/de/support/download/omada-software-controller/#Controller_Software";
  #  sha256 = "0r0g9v5nfj6ac430dblydc9vf690sfw0niqkarr1m678pfkgnr3g";
  #};

  src = fetchzip {
    url = "https://static.tp-link.com/upload/software/2022/202205/20220507/Omada_SDN_Controller_v5.3.1_Linux_x64.tar.gz";
    hash = "sha256-sXMJGefAlXrr2YatMHBKLCHsaZC/o3dk6y4QLGvnjvo=";
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

