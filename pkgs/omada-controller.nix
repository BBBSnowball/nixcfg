# nix-build -E '(import <nixpkgs> {}).callPackage ./omada-controller.nix {}'
{ stdenv, fetchzip, openjdk, mongodb, mongodb-ce }:
let
  # The precompiled one seems to be a newer release. Be careful when switching back and forth.
  #chosenMongodb = mongodb;    # build from sources - takes ages, Hydra doesn't build it due to non-free license
  chosenMongodb = mongodb-ce;  # precompiled build. That sucks but our Omada controller hardware is built for saving power, not running a compiler...
in
stdenv.mkDerivation {
  pname = "omada-controller";
  version = "5.13.30.8";

  src = fetchzip {
    # https://support.omadanetworks.com/en/product/omada-software-controller/?resourceType=download  (English download page, seems to be more up-to-date)
    url = "https://static.tp-link.com/upload/software/2025/202510/20251031/Omada_SDN_Controller_v6.0.0.24_linux_x64_20251027202524.tar.gz";
    hash = "sha256-tZL4qGF2NTcizsn0nteY1joUtTascjxPGxwFcFGhcfo=";
    stripRoot = false;

    #NOTE v5.15.20: I had to update permissions on both hosts: chmod u+w /var/lib/omada-controller/properties/omada.properties
  };

  buildInputs = [
    openjdk
    chosenMongodb
  ];

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
    ln -s ${chosenMongodb}/bin/mongod $out/bin/mongod
  '';

  meta.platforms = [ "x86_64-linux" ];
}

