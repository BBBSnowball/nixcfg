{ pkgs, ... }:
let
  extraContainerSource = pkgs.fetchFromGitHub {
    owner = "erikarvstedt";
    repo = "extra-container";
    rev = "af89924644a133fa9119da959367a9653600f33d";
    sha256 = "sha256-QbkT5+o3p2bdPX3hdlBavxL+sFQx/3sX1Kv7ekGuJ38=";
  };
  extra-container = pkgs.callPackage extraContainerSource { pkgSrc = extraContainerSource; };
in
{
  environment.systemPackages = [ extra-container ];
}
