{ pkgs, routeromen, ... }:
rec {
  provideArgsToModule = args: m: args2@{ ... }: with pkgs.lib;
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
       else builtins.throw "Override the input `private`, e.g. by passing this to nixos-rebuild: --override-input private path:/etc/nixos/hosts/${hostname}/private/data");

  mkFlakeForHostConfig = hostname: system: mainConfigFile: flakeInputs@{ self, nixpkgs, ... }: let
     extraArgs = flakeInputs // { inherit withFlakeInputs private; modules = self.nixosModules; };
     withFlakeInputs = provideArgsToModule extraArgs;
     mainModule = withFlakeInputs mainConfigFile;
     private = getPrivateData flakeInputs hostname;
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
