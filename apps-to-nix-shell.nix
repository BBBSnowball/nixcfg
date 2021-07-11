{ inNixShell ? false, system ? builtins.currentSystem, appToBuild ? null }:
with builtins;
let
  lock = fromJSON (readFile ./flake.lock);
  flake-compat =
    if lock.nodes.flake-compat.locked ? url && substring 0 7 lock.nodes.flake-compat.locked.url == "file://"
    then substring 7 (-1) lock.nodes.flake-compat.locked.url
    else fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    };
  flakeAll = import flake-compat { src = ./.; };
  flake = flakeAll.defaultNix;

  lib = flake.inputs.nixpkgs.lib;
  nixpkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  flakePkgs = flake.packages.${system};
  pkgs = nixpkgs // flakePkgs;
  apps = flake.apps.${system};

  drvAsContext = drvPath: appendContext drvPath { ${drvPath} = { outputs = [ "out" ]; }; };
  # This doesn't work because it will build the outputs of the derivation. If we omit drvAsContext, it won't have the derivation as a requisite.
  makeProgramLazy1 = name: program: nixpkgs.writeShellScriptBin name ''
    nix-build --no-out-link ${builtins.toString (map drvAsContext (attrNames (getContext program)))} >/dev/null || exit $?
    exec "${builtins.unsafeDiscardStringContext app.program}" "$@"
  '';
  #buildApp = nixpkgs.linkFarm appToBuild (map (drvPath: ) (attrNames (getContext apps.${appToBuild}.program)));
  buildApp = let program = apps.${appToBuild}.program; in
  nixpkgs.writeShellScript "build-${appToBuild}" ''
    exec nix-build --no-out-link ${builtins.toString (map drvAsContext (attrNames (getContext program)))} >/dev/null
  '';
  makeProgramLazy = name: program: nixpkgs.writeShellScriptBin name ''
    set -e
    shopt -s inherit_errexit
    bash $(nix-build "${toString ./.}" -A buildApp --argstr appToBuild "${name}")
    exec "${builtins.unsafeDiscardStringContext program}" "$@"
  '';
  makeAppLazy = name: app:
    if (app.type or "") != "app" || !(app ? program)
    then nixpkgs.writeShellScriptBin name ''
      echo "invalid app" >&2
      exit 1
    ''
    else makeProgramLazy name app.program;
  lazyApps = nixpkgs.symlinkJoin { name = "apps"; paths = lib.attrsets.mapAttrsToList makeAppLazy apps; };
in
pkgs.mkShell {
  buildInputs = [
    lazyApps
  ];

  #NOTE We must return a single derivation for nix-shell but the user
  #     may be using `nix-shell -A attr`, in which case we want to make
  #     all packages available. This is an ugly workaround and it may
  #     very well break for package names that match some of the attributes
  #     in the mkShell derivation.
  passthru = flakePkgs // { inherit apps pkgs buildApp; x = builtins.getContext (toString ./.); y = 43; x2 = toString ./.; };
}
