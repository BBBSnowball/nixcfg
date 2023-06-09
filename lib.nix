{ pkgs, routeromen, ... }:
let
  lib = pkgs.lib;
  inherit (lib) isFunction isAttrs;
in
rec {
  # copied from nixpkgs because they have deprecated the export
  # https://github.com/NixOS/nixpkgs/blob/f47f0a525cac079318e62fef27439f17afa18e7a/lib/modules.nix#LL456C1-L490C9
  /* Massage a module into canonical form, that is, a set consisting
     of ‘options’, ‘config’ and ‘imports’ attributes. */
  unifyModuleSyntax = file: key: m:
    with lib;
    let
      addMeta = config: if m ? meta
        then mkMerge [ config { meta = m.meta; } ]
        else config;
      addFreeformType = config: if m ? freeformType
        then mkMerge [ config { _module.freeformType = m.freeformType; } ]
        else config;
    in
    if m ? config || m ? options then
      let badAttrs = removeAttrs m ["_class" "_file" "key" "disabledModules" "imports" "options" "config" "meta" "freeformType"]; in
      if badAttrs != {} then
        throw "Module `${key}' has an unsupported attribute `${head (attrNames badAttrs)}'. This is caused by introducing a top-level `config' or `options' attribute. Add configuration attributes immediately on the top level instead, or move all of them (namely: ${toString (attrNames badAttrs)}) into the explicit `config' attribute."
      else
        { _file = toString m._file or file;
          _class = m._class or null;
          key = toString m.key or key;
          disabledModules = m.disabledModules or [];
          imports = m.imports or [];
          options = m.options or {};
          config = addFreeformType (addMeta (m.config or {}));
        }
    else
      # shorthand syntax
      lib.throwIfNot (isAttrs m) "module ${file} (${key}) does not look like a module."
      { _file = toString m._file or file;
        _class = m._class or null;
        key = toString m.key or key;
        disabledModules = m.disabledModules or [];
        imports = m.require or [] ++ m.imports or [];
        options = {};
        config = addFreeformType (removeAttrs m ["_class" "_file" "key" "disabledModules" "require" "imports" "freeformType"]);
      };

  applyModuleArgsIfFunction = key: f: args@{ config, options, lib, ... }:
    if isFunction f then applyModuleArgs key f args else f;

  applyModuleArgs = key: f: args@{ config, options, lib, ... }:
    let
      # Module arguments are resolved in a strict manner when attribute set
      # deconstruction is used.  As the arguments are now defined with the
      # config._module.args option, the strictness used on the attribute
      # set argument would cause an infinite loop, if the result of the
      # option is given as argument.
      #
      # To work-around the strictness issue on the deconstruction of the
      # attributes set argument, we create a new attribute set which is
      # constructed to satisfy the expected set of attributes.  Thus calling
      # a module will resolve strictly the attributes used as argument but
      # not their values.  The values are forwarding the result of the
      # evaluation of the option.
      context = name: ''while evaluating the module argument `${name}' in "${key}":'';
      extraArgs = builtins.mapAttrs (name: _:
        builtins.addErrorContext (context name)
          (args.${name} or config._module.args.${name})
      ) (lib.functionArgs f);

      # Note: we append in the opposite order such that we can add an error
      # context on the explicit arguments of "args" too. This update
      # operator is used to make the "args@{ ... }: with args.lib;" notation
      # works.
    in f (args // extraArgs);


  
  provideArgsToModule = args: m: args2@{ ... }: with pkgs.lib;
    # see https://github.com/NixOS/nixpkgs/blob/c45ccae27bb29fd398261c3c915d5a94e422ffef/lib/modules.nix#L377
    if isFunction m || isAttrs m
      then unifyModuleSyntax "<unknown-file>" "" (applyModuleArgsIfFunction "" m (args // args2))
      else unifyModuleSyntax (toString m) (toString m) (applyModuleArgsIfFunction (toString m) (import m) (args // args2));

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
      private = getPrivateData flakeInputs hostname;
      subFlake = self;
      mainFlake = flakeInputs.routeromen;
    };
    # We can mostly use config._module.args instead of this but that won't work for `modules`
    # because we need that before config is available.
    extraArgsForImports = {
      modules = self.nixosModules;
      inherit withFlakeInputs withFlakeInputs';
    };
    withFlakeInputs' = moreArgs: provideArgsToModule (flakeInputs // extraArgs // extraArgsForImports // moreArgs);
    withFlakeInputs = withFlakeInputs' {};
    mainModule = {
      imports = [
        (withFlakeInputs mainConfigFile)
        { _module.args = flakeInputs // extraArgs; }
      ];
    };
  in {
     lib.withFlakeInputs = withFlakeInputs;

     nixosModules.default = mainModule;
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
