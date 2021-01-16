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
  } // (let
    supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    stuff = forAllSystems (system: import ./riscv/compiler.nix { inherit nixpkgs system; });
  in {
    packages = forAllSystems (system: with stuff.${system}; { rustc-gd32 = rustc; cargo-gd32 = cargo; gcc-gd32 = gcc; });
    apps = forAllSystems (system: {
      gcc-gd32   = { type = "app"; program = "${self.packages.${system}.gcc-gd32}/bin/gcc"; };
      rustc-gd32 = { type = "app"; program = "${self.packages.${system}.rustc-gd32}/bin/rustc"; };
      cargo-gd32 = { type = "app"; program = "${self.packages.${system}.cargo-gd32}/bin/cargo"; };
    });
  });
}
