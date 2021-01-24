{ pkgs, ... }:
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

  mkFlakeForHostConfig = hostname: system: mainConfigFile: flakeInputs@{ self, nixpkgs, ... }: let
     extraArgs = flakeInputs // { inherit withFlakeInputs; modules = self.nixosModules; };
     withFlakeInputs = provideArgsToModule extraArgs;
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
