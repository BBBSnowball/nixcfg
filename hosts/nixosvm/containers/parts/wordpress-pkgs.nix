let
  overlay = final: prev: with final; let
    fetchTheme = { url, hash }: let
      nameParts = with builtins; match "(.*/)?([^.]+)[.]([0-9.]+)[.][a-z]+" url;
    in stdenv.mkDerivation {
      name = builtins.elemAt nameParts 1;
      version = builtins.elemAt nameParts 2;
      src = fetchzip { inherit url hash; };
      nativeBuildInputs = [ unzip ];
      installPhase = ''mkdir -p $out; cp -R * $out/'';
    };
  in {
    myWordpressPlugins = {
      passwordProtectPlugin = fetchzip {
        url = "https://downloads.wordpress.org/plugin/password-protected.2.7.4.zip";
        sha256 = "sha256-6kU4duN3V/z0jIiShxzCHTG2GIZPKRook0MIQVXWLQg=";
      };
    };

    myWordpressThemes = {
      oceanwp         = fetchTheme { url = "https://downloads.wordpress.org/theme/oceanwp.4.0.2.zip";       hash = "sha256-cNcdLYWcAz9/Wqr2dTa8m97VCq7i/IoX17Fu6ZTzmjs="; };
      #neve            = fetchTheme { url = "https://downloads.wordpress.org/theme/neve.3.2.5.zip";          hash = "sha256-pMRwBN6B6eA3zmdhLnw2zSoGR6nKJikE+1axrzINQw8="; };
      neve            = fetchTheme { url = "https://downloads.wordpress.org/theme/neve.3.8.13.zip";         hash = "sha256-hJ0noKHIZ+SXSIy0z3ixCJNqcc/nFIXezqJ+sz7qzlc="; };
      ashe            = fetchTheme { url = "https://downloads.wordpress.org/theme/ashe.2.246.zip";          hash = "sha256-87yWJhuXSfpp6L30/P9kN8jcqYVFLKlXU0NXCppUGrA="; };
      twentyseventeen = fetchTheme { url = "https://downloads.wordpress.org/theme/twentyseventeen.3.8.zip"; hash = "sha256-4GOzQtvre7ifYe7oQPFPcD+WRmZZ9G5OZcuRFZ92fw4="; };
    };
  };
in
{
  nixpkgs.overlays = [ overlay ];
}
