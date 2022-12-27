let
  mach-nix = import (builtins.fetchGit {
    url = "https://github.com/DavHau/mach-nix/";
    # place version number with the latest one from the github releases page
    ref = "refs/tags/3.5.0";
  }) {};
in
mach-nix.mkPython {
  requirements = ''
    cadquery==2.2.0b2
    #cadquery-server
    #cq-editor
  '';
}
