let
  # We replace some builtin functions to trace which files are
  # read via these functions. The idea is based on lorri:
  # https://github.com/target/lorri/blob/60c00d56484b164614c41e2f3df35a93dbdbb75c/src/logged-evaluation.nix#L8
  builtins2 = builtins;
  importScopedWithWatch = parentScope@{ builtins ? builtins2, ... }: let
    withWatchTrace = f: arg: builtins.trace "direnv watch_file: ${toString arg}" (f arg);
    scope = parentScope // {
      builtins = builtins // {
        readFile = withWatchTrace builtins.readFile;
        readDir  = withWatchTrace builtins.readDir;
      };
      import = withWatchTrace (builtins.scopedImport scope);
      #scopedImport = x: withWatchTrace (importScopedWithWatch (parentScope // x));
      scopedImport = x: withWatchTrace (importScopedWithWatch (x // scope));
    };
  in scope.import;

  callIfFunction = x: if builtins.isFunction x then x {} else x;

  #FIXME We should install this file to Nix store and hardcode the paths.
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  exportEnv = d: d.overrideAttrs (_: {
    # We use the same trick as pkgs.mkShell and thereby undo its "do not build" trick.
    # see https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/mkshell/default.nix
    phases = ["exportVarsPhase"];
    _DIRENV_OLD_phases = d.phases or [];
    exportVarsPhase = ''
      # We don't want some of the variables.
      # see https://github.com/target/lorri/blob/1aedb78b59df55c33aa6fcf5675360a2ee4e594c/src/ops/direnv/envrc.bash#L126
      unset HOME USER LOGNAME DISPLAY TERM IN_NIX_SHELL TZ PAGER NIX_BUILD_SHELL SHLVL TEMPDIR TMPDIR TEMP TMP NIX_ENFORCE_PURITY OLDPWD PWD SHELL
      unset NIX_LOG_FD
      export phases="$_DIRENV_OLD_phases"
      unset exportVarsPhase nobuildPhase _DIRENV_OLD_phases
      ( unset PATH out; export ) >$out
    '';
  });
  makeEnvrcStdenvSetup = d: pkgs.writeShellScript "envrc-${d.name or "shell"}" ''
    . ${exportEnv d}
    export IN_NIX_SHELL=impure
    export noDumpEnvVars=1
    [ -n "$stdenv" -a -f $stdenv/setup ] && . $stdenv/setup
  '';
  makeEnvrcPathOnly = d: let
    inputAttrs = ["buildInputs" "nativeBuildInputs" "propagatedBuildInputs" "propagatedNativeBuildInputs"];
    getDefault = attr: default: if builtins.hasAttr attr d then builtins.getAttr attr d else default;
    getInputs = x: (lib.concatLists (builtins.map (attr: getDefault attr []) inputAttrs)) ++ (lib.concatLists (builtins.map getInputs (x.inputsFrom or [])));
    paths = getInputs d;
    #otherVars = builtins.removeAttrs d (inputAttrs ++ ["name" "phases" "inputsFrom"]);
    otherVars = builtins.removeAttrs d ["name" "phases" "inputsFrom"];
    tryToString = x: with builtins;
      if isBool x || isString x || isInt x || isPath x || x ? __toString then toString x
      else if isList x then toString (map tryToString x)
      else null;
    otherVarsStr = lib.filterAttrs (n: v: v != null && n >= "A" && n < "[") (lib.mapAttrs (n: v: tryToString v) otherVars);
  in pkgs.writeShellScript "envrc-${d.name or "shell"}" ''
    #FIXME only for dirs that exist
    PATH=${lib.escapeShellArg (lib.concatStringsSep ":" (map (x: "${x}/bin") paths))}:"$PATH"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "export ${lib.escapeShellArg name}=${lib.escapeShellArg value}") otherVarsStr)}
    # ${toString (lib.mapAttrsToList (n: v: "${n} (${builtins.typeOf v})") d)}
  '';
  makeEnvrc = d: let mode = d.mode or "stdenv-setup"; in
    if mode == "stdenv-setup" then makeEnvrcStdenvSetup d
    else if mode == "path-only" then makeEnvrcPathOnly d
    else builtins.abort "invalid mode";
in makeEnvrc (callIfFunction (importScopedWithWatch {} ./shell.nix))

