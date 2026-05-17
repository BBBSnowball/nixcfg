{ lib, pkgs, nixpkgs-small, ... }:
let
  isPatched = pkg: lib.lists.any (p: (lib.strings.match ".*-CVE-2026-40460[.]patch$" (toString p)) != null) pkg.patches;
  isOk = nginx: nginx.version != "1.28.3" || isPatched nginx;
  system = pkgs.stdenv.hostPlatform.system;
  chooseNginx = prev: name: let
    normal = prev.${name};
    small = nixpkgs-small.legacyPackages.${system}.${name};
  in if isOk normal || lib.versionOlder small.version normal.version then normal else small;
in
{
  config.nixpkgs.overlays = [ (final: prev: {
    nginx = chooseNginx prev "nginx";
    nginxStable = chooseNginx prev "nginxStable";
  }) ];
}
