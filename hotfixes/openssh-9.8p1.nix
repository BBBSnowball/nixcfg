# see https://github.com/NixOS/nixpkgs/pull/323753
final: prev:
let
  name = "openssh";
  lib = final.lib;
  pkg = prev.${name};
  fixedVersion = "9.8p1";
in {
  ${name} =
  if lib.versionAtLeast pkg.version fixedVersion || lib.lists.any (p: lib.strings.match ".*CVE-2024-6387.*" (toString p) != null) pkg.patches
  then builtins.trace "hotfix not used for ${pkg.name} because it is not older than ${fixedVersion}" pkg
  else pkg.overrideAttrs (old: rec {
    name = "${old.pname}-${version}";
    version = fixedVersion;
    src = final.fetchurl {
      url = "mirror://openbsd/OpenSSH/portable/openssh-${version}.tar.gz";
      hash = "sha256-3YvQAqN5tdSZ37BQ3R+pr4Ap6ARh9LtsUjxJlz9aOfM=";
    };
  });
}
