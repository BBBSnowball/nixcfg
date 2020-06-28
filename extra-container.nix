{ pkgs, ... }:
let
  extraContainerSource = pkgs.fetchFromGitHub {
    owner = "erikarvstedt";
    repo = "extra-container";
    rev = "a6962448872e1a8510cc3c1a5898fc11d728a32f";
    sha256 = "0hf8j1zj8p9c5h71xwqa45w75ksjjgwhad1aad6wsnazvq6wdxsf";
  };
  extra-container = pkgs.callPackage extraContainerSource { pkgSrc = extraContainerSource; };
in
{
  environment.systemPackages = [ extra-container ];
}
