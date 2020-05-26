let
  # We replace some builtin functions to trace which files are
  # read via these functions. The idea is based on lorri:
  # https://github.com/target/lorri/blob/60c00d56484b164614c41e2f3df35a93dbdbb75c/src/logged-evaluation.nix#L8
  builtins2 = builtins;
  importScopedWithWatch = parentScope@{ builtins ? builtins2, ... }: let
    withWatchTrace = f: arg: builtins.trace "direnv watch_file '${toString arg}'" (f arg);
    scope = parentScope // {
      builtins = builtins // {
        readFile = withWatchTrace builtins.readFile;
        readDir  = withWatchTrace builtins.readDir;
      };
      import = builtins.scopedImport scope;
      #scopedImport = x: importScopedWithWatch (parentScope // x);
      scopedImport = x: importScopedWithWatch (x // scope);
    };
  in scope.import;

  callIfFunction = x: if builtins.isFunction x then x {} else x;
in callIfFunction (importScopedWithWatch {} ./shell.nix)

