final: prev:
let
  pkgs = final;
  lib = pkgs.lib;

  speedtestPlugin = pkgs.fetchFromGitHub {
    owner = "mad-ady";
    repo  = "smokeping-speedtest";
    rev   = "c0d4a60cc7eb8b18c5879797cbf0be81e18ce790";  # 2020-05-22
    sha256 = "sha256-ribrGZgVDW5/aXY8obs9+ZRczWYZlC8vZ9FZvcY7zus=";
  };

  # speedtest values can be higher than 180
  smokepingLargeValuesPatch = pkgs.fetchurl {
    url = "https://github.com/oetiker/SmokePing/commit/60419834f224a0735094fd4ad0aac8eac3b15289.patch";
    sha256 = "sha256-2Bu5RHkigLx7uE2F1GScawssg6sY+LDeOUxqtM4n8kc=";
  };
in {
  smokeping = prev.smokeping.overrideAttrs (old: {
    patches = (old.patches or []) ++ lib.optionals (! lib.versionAtLeast prev.smokeping.version "2.8.2") [
      ./smokeping-drop-rsa1.patch
      ./smokeping-drop-dsa.patch
      smokepingLargeValuesPatch
    ];
    postInstall = (old.postInstall or "") + ''
      # add speedtest plugin
      cp ${speedtestPlugin}/*.pm $out/lib/Smokeping/probes/
    '';
  });
}
