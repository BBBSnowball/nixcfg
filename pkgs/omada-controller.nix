# nix-build -E '(import <nixpkgs> {}).callPackage ./omada-controller.nix {}'
{ stdenv, fetchzip, openjdk, mongodb }:
stdenv.mkDerivation {
  pname = "omada-controller";
  version = "5.13.30.8";

  src = fetchzip {
    # https://www.tp-link.com/de/support/download/omada-software-controller/
    # https://support.omadanetworks.com/en/product/omada-software-controller/?resourceType=download  (English download page, seems to be more up-to-date)
    url = "https://static.tp-link.com/upload/software/2025/202504/20250425/Omada_SDN_Controller_v5.15.20.20_linux_x64_20250416110546.tar.gz";  # from the link above
    # Not available on TP Link website, yet, it seems -> only available on the English page:
    #url = "https://download.tplinkcloud.com/firmware/Omada_SDN_Controller_v5.15.20.20_linux_x64_20250416110546_1745551413090.tar.gz";  # from webinterface of controller
    hash = "sha256-4iLoERHpTuUe6feHWp258KtOw2XPWUyWbaQFcpIRNYk=";
    stripRoot = false;

    #NOTE v5.15.20: I had to update permissions on both hosts: chmod u+w /var/lib/omada-controller/properties/omada.properties
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

