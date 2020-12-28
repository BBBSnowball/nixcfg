{
  description = "Config for routeromen, some modules are also used on other hosts";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  inputs.jens-dotfiles.url = "gitlab:jens/dotfiles/cbded47f57fa7c5819709f2a2e97ea29af9b321a?host=git.c3pb.de";
  inputs.jens-dotfiles.flake = false;
  inputs.private.url = "path:./private";
  inputs.private.flake = false;

  outputs = { self, nixpkgs, ... }: {
    lib = import ./lib.nix { pkgs = nixpkgs; };

    nixosModules = import ./modules.nix { inherit self; };

    # The common module includes all the settings and modules that I want to apply to all systems.
    nixosModule = self.nixosModules.common;
 
    nixosConfigurations.routeromen = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
       [ (self.lib.provideArgsToModule (self.inputs // { modules = self.nixosModules; }) ./configuration.nix)
          ({ pkgs, ... }: {
            _file = "${self}/flake.nix#inline-config";
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
          })
        ];
    };
  };
}
