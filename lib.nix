{ pkgs, routeromen, ... }:
rec {
  applyIfFunction = pkgs.lib.applyIfFunction or pkgs.lib.applyModuleArgsIfFunction;

  provideArgsToModule = args: m: args2@{ ... }: with pkgs.lib;
    # see https://github.com/NixOS/nixpkgs/blob/c45ccae27bb29fd398261c3c915d5a94e422ffef/lib/modules.nix#L377
    if isFunction m || isAttrs m
      then unifyModuleSyntax "<unknown-file>" "" (applyIfFunction "" m (args // args2))
      else unifyModuleSyntax (toString m) (toString m) (applyIfFunction (toString m) (import m) (args // args2));

  mkModuleForConfigurationRevision = { self, nixpkgs, ... }: { ... }: {
    # Let 'nixos-version --json' know about the Git revision
    # of this flake.
    system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

    _file = "${self}/lib.nix#mkModuleForConfigurationRevision";
  };

   getPrivateData = flakeInputs: hostname:
     #nixpkgs.lib.debug.traceSeqN 2 ([ (self.inputs.private or {}) private ])
     (if (routeromen.inputs.private.rev or "") != "ab7ab3690bdb7f662bb386e554d953dc8200c977"
       then routeromen.inputs.private  # not the dummy flake
       else builtins.throw ("Override the input `private`, e.g. by passing this to nixos-rebuild: --override-input private path:/etc/nixos/hosts/${hostname}/private/data/"
         + "\nIf this is for a sub-flake, override routeromen/private instead."));

  mkFlakeForHostConfig = hostname: system: mainConfigFile: flakeInputs@{ self, nixpkgs, ... }: let
    extraArgs = rec {
      modules = self.nixosModules;
      private = getPrivateData flakeInputs hostname;
      privateForHost = let
        outPath = "${private}/by-host/${hostname}";
        #FIXME make config available to a function in values
        values = if builtins.pathExists "${outPath}/default.nix" then import outPath else {};
      in values // { inherit outPath; };
      secretForHost = "/etc/nixos/secret/by-host/${hostname}";
      inherit withFlakeInputs withFlakeInputs';
    };
    withFlakeInputs' = moreArgs: provideArgsToModule (flakeInputs // extraArgs // moreArgs);
    withFlakeInputs = withFlakeInputs' {};
    mainModule = withFlakeInputs mainConfigFile;
  in {
     lib.withFlakeInputs = withFlakeInputs;

     nixosModule = mainModule;
     nixosModules.main = mainModule;

     nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
       inherit system;
       modules =
         [ mainModule
           (mkModuleForConfigurationRevision flakeInputs)
           { networking.hostName = hostname; }
         ];
     };
  };
}
