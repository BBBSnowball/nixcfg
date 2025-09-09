let
  overlay = final: prev: with final; let
    fetchPart = { url, hash, ... }@args: let
      nameParts = with builtins; match "(.*/)?([^.]+)[.]([0-9.]+)[.][a-z]+" url;
    in stdenv.mkDerivation ({
      name = builtins.elemAt nameParts 1;
      version = builtins.elemAt nameParts 2;
      src = fetchzip { inherit url hash; };
      nativeBuildInputs = [ unzip ];
      installPhase = ''mkdir -p $out; cp -R * $out/'';
    } // lib.removeAttrs args ["url" "hash"]);
    fetchTheme = fetchPart;
    fetchPlugin = fetchPart;
    
    generated = final.callPackage ../wordpress/wp.nix {};
  in {
    myWordpressPlugins = generated.plugins // {
      # This could probably use fetchPlugin but we keep it as it was, for now.
      passwordProtectPlugin = fetchzip {
        url = "https://downloads.wordpress.org/plugin/password-protected.2.7.4.zip";
        sha256 = "sha256-6kU4duN3V/z0jIiShxzCHTG2GIZPKRook0MIQVXWLQg=";
      };

      # keep manual fetch because it doesn't seem to exist anymore
      caldavlist = fetchPlugin {
        url = "https://downloads.wordpress.org/plugin/caldavlist.1.1.4.zip";
        hash = "sha256-2pbcOixbU1Ume9iPIzIp7KfRJrMnWY8/57rzGRrTbEE=";

        postPatch = ''
          substituteInPlace dist/caldavlist.js \
            --replace-fail 't.categories.join(", ")+" - "+t.title' 't.title+" ("+t.categories.join(", ")+")"'
        '';
      };
    };

    myWordpressThemes = generated.themes;
  };
in
{
  nixpkgs.overlays = [ overlay ];
}
