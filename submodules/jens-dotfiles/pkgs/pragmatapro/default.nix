{ runCommand, requireFile, unzip }:

let
  name = "pragmatapro-${version}";
  version = "0.828";
in

runCommand name
  rec {
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-+92EgbGP/LbSnOyBQ209AORsVYDXkmmWdT3vVxNGxzQ=";

    src = requireFile rec {
      name = "PragmataPro${version}.zip";
      url = "https://fsd.it/shop/fonts/pragmatapro/";
      sha256 = "4c82841cf8f37002ec3eb7972efb669bdf14daa900062c94fed37383c84c19af";
    };

    buildInputs = [ unzip ];
  } ''
    unzip $src
    install_path=$out/share/fonts/truetype/pragmatapro
    mkdir -p $install_path
    find -name "PragmataPro*.ttf" -exec mv {} $install_path \;
  ''
