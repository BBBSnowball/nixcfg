# based on https://github.com/NixOS/nixpkgs/blob/6ed000269b404d690c4927400788ddfef98f0eae/pkgs/applications/networking/instant-messengers/element/element-web.nix
{ lib, stdenv, fetchurl, writeText, jq, conf ? {} }:

# Note for maintainers:
# Versions of `element-web` and `element-desktop` should be kept in sync.

let
  noPhoningHome = {
    disable_guests = true; # disable automatic guest account registration at matrix.org
    piwik = false; # disable analytics
  };
  configOverrides = writeText "element-config-overrides.json" (builtins.toJSON (noPhoningHome // conf));

in stdenv.mkDerivation rec {
  pname = "element-web";
  version = "1.9.9";

  src = fetchurl {
    url = "https://github.com/vector-im/element-web/releases/download/v${version}/element-v${version}.tar.gz";
    hash = "sha256-TgamhKFCh4u0VC9TdhCfq5XfDE8m/c/LziRYx5Kaf8Q=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/
    cp -R . $out/
    ${jq}/bin/jq -s '.[0] * .[1]' "config.sample.json" "${configOverrides}" > "$out/config.json"

    runHook postInstall
  '';

  meta = {
    description = "A glossy Matrix collaboration client for the web";
    homepage = "https://element.io/";
    changelog = "https://github.com/vector-im/element-web/blob/v${version}/CHANGELOG.md";
    maintainers = lib.teams.matrix.members;
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
    hydraPlatforms = [];
  };
}
