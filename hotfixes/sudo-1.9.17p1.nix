# see https://github.com/NixOS/nixpkgs/pull/323753
final: prev:
let
  name = "sudo";
  lib = final.lib;
  pkg = prev.${name};
  fixedVersion = "1.9.17p1";
in {
  ${name} =
  if lib.versionAtLeast pkg.version fixedVersion || lib.lists.any (p: lib.strings.match ".*CVE-2025-32463.*" (toString p) != null) pkg.patches
  then #builtins.trace "hotfix not used for ${pkg.name} because it is not older than ${fixedVersion}"
       pkg
  else pkg.overrideAttrs (old: rec {
    name = "${old.pname}-${version}";
    version = fixedVersion;
    src = final.fetchurl {
      url = "https://www.sudo.ws/dist/sudo-${version}.tar.gz";
      hash = "sha256-/2B+pxcHIZdzinj3eGks1t+afj5ARWX1HeBjyidFXTI=";
    };
  });
}
