{
  description = "Config for my NixOS hosts";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";
  inputs.nixpkgs-mongodb.url = "github:NixOS/nixpkgs/nixos-22.11";

  #inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.url = "github:BBBSnowball/flake-compat";
  inputs.flake-compat.flake = false;

  inputs.jens-dotfiles.url = "gitlab:jens/dotfiles/cbded47f57fa7c5819709f2a2e97ea29af9b321a?host=git.c3pb.de";
  inputs.jens-dotfiles.flake = false;

  inputs.private.url = "github:BBBSnowball/nixcfg/dummy";
  inputs.private.flake = false;

  #inputs.nix-bundle.url = "github:matthewbauer/nix-bundle";
  inputs.nix-bundle.url = "github:BBBSnowball/nix-bundle";
  inputs.nix-bundle.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs1: let outputFunction = { self, nixpkgs, nix-bundle, nixpkgs-mongodb, flake-compat, private, ... }: (let
    nixosSystemModule = path: {
      imports =
        [ (self.lib.provideArgsToModule ({ modules = self.nixosModules; }) path)
          ({ pkgs, ... }: {
            _file = "${self}/flake.nix#inline-config";
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

            _module.args = self.inputs // {
              modules = self.nixosModules;
              inherit self;
              mainFlake = self;
            };
          })
        ];
    };

    # getFlake doesn't work here when in pure mode so we use flake-compat.
    getSubFlake = path: (import flake-compat {
      src = path;
      outputFunctionOverrides.routeromen = inputs: outputFunction (inputs1 // removeDummyFlakes inputs);
      inputOverrides = { inherit private; };
    }).defaultNix;
    getFlakeForHost = name: (getSubFlake (./hosts + "/${name}"));
    mkHostInSubflake = name: (getFlakeForHost name).nixosConfigurations.${name};
    removeDummyFlakes = inputs1.nixpkgs.lib.attrsets.filterAttrs (key: x: key == "self" || !(x ? emptyDummyFlake));
  in {
    lib = import ./lib.nix { pkgs = nixpkgs; routeromen = self; };

    nixosModules = import ./modules.nix { inherit self; } // {
      hosts-routeromen = nixosSystemModule hosts/routeromen;
      raspi-zero-usbboot = import ./raspi-zero/usbboot.nix;
      raspi-pico = import ./raspi-pico;
      # The common module includes all the settings and modules that I want to apply to all systems.
      default = self.nixosModules.common;
    };
 
    nixosConfigurations.routeromen = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ self.nixosModules.hosts-routeromen ];
    };

    nixosConfigurations.rockpro64-snowball = mkHostInSubflake "rockpro64-snowball";
    nixosConfigurations.nixosvm = mkHostInSubflake "nixosvm";
    nixosConfigurations.c3pbvm = mkHostInSubflake "c3pbvm";
    nixosConfigurations.gk3v-pb = mkHostInSubflake "gk3v-pb";
    nixosConfigurations.hetzner-gos = mkHostInSubflake "hetzner-gos";
    nixosConfigurations.hetzner-temp = mkHostInSubflake "hetzner-temp";
    nixosConfigurations.framework = self.nixosConfigurations.fw;
    nixosConfigurations.fw = mkHostInSubflake "fw";
    nixosConfigurations.fwa = mkHostInSubflake "fwa";
    nixosConfigurations.orangepi-remoteadmin = mkHostInSubflake "orangepi-remoteadmin";
    nixosConfigurations.gpd = mkHostInSubflake "gpd";
    nixosConfigurations.m1 = mkHostInSubflake "m1";
    nixosConfigurations.macnix = self.nixosConfigurations.m1;
    nixosConfigurations.sonline0 = mkHostInSubflake "sonline0";
    nixosConfigurations.bettina-home = mkHostInSubflake "bettina-home";
    nixosConfigurations.ug1 = mkHostInSubflake "ug1";
  } // (let
    supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];  #NOTE I only have an aarch64-darwin so x86 is completely untested!
    forDarwinSystems = nixpkgs.lib.genAttrs darwinSystems;
    gd32 = forAllSystems (system: import ./riscv/compiler.nix { inherit nixpkgs system; });
    rppico = forAllSystems (system: import ./raspi-pico/toolchain.nix { inherit nixpkgs system; });
    purethermal = forAllSystems (system: import ./pkgs/purethermal-firmware.nix { inherit nixpkgs system; lib = nixpkgs.lib; });
    flipperzero = forAllSystems (system: import ./pkgs/flipperzero.nix { inherit nixpkgs system; lib = nixpkgs.lib; });
  in {
    packages = forAllSystems (system: let pkgs = nixpkgs.legacyPackages.${system}; in {
      nrfjprog = pkgs.callPackage ./embedded/nrfjprog.nix {};
      #apio = pkgs.callPackage ./embedded/apio.nix {};
      wlay = pkgs.callPackage ./pkgs/wlay.nix {};
      GetThermal = pkgs.libsForQt5.callPackage ./pkgs/GetThermal.nix {};
      purethermal-firmware = purethermal.${system}.firmware;
      purethermal-firmware-upstream = purethermal.${system}.firmware-upstream;
      purethermal-firmware-original-bin = purethermal.${system}.firmware-original-bin;
      flipperzero-firmware = flipperzero.${system};
      #pip2nix = pkgs.callPackage ./pkgs/pip2nix.nix { inherit pkgs; nixpkgs = "blub"; };  # broken
      openups = pkgs.callPackage ./pkgs/openups.nix {};
      openups-aarch64-static = let p = pkgs.pkgsCross.aarch64-multiplatform-musl.pkgsStatic; in
      (p.callPackage ./pkgs/openups.nix {}).overrideAttrs (old: {
        patches = (old.patches or []) ++ [ ./pkgs/openups-static.patch ];
        buildInputs = (old.buildInputs or []) ++ [ p.libusb ];
      });
      openups-aarch64-static-dbg = self.packages.${system}.openups-aarch64-static.overrideAttrs (old: {
        postPatch = ''
          sed -i 's/#undef DEBUG_RECV/#define DEBUG_RECV 1/' src/lib/usbhid.cpp
        '';
      });
      add_recently_used = pkgs.callPackage ./pkgs/add_recently_used.nix {};
      muninlite = pkgs.callPackage ./pkgs/muninlite.nix {};
      tailscale-derpprobe = pkgs.tailscale.overrideDerivation (_: { subPackages = [ "cmd/derpprobe" ]; postInstall = ""; });
      plymouth-subraum = pkgs.callPackage ./pkgs/plymouth-subraum {};
    } // (with gd32.${system}; {
      gcc-gd32 = gcc; binutils-gd32 = binutils; openocd-gd32 = openocd-nuclei; gdb-gd32 = gdb-nuclei;
      rustc-gd32 = rustc; cargo-gd32 = cargo;
    }) // (with rppico.${system}; {
      gcc-rppico = gcc; binutils-rppico = binutils; gdb-rppico = gdb;
      inherit openocd-rppico picotool pioasm elf2uf2 picoprobe picosdk;
      inherit picoexamples picoplayground picoextras;
      rppicoShell = shell;
    })
    // (let x = import ./raspi-zero/overlay.nix (pkgs // x // { nixpkgsPath = nixpkgs; }) pkgs; in x)
    // (let sub = getFlakeForHost "sonline0-initrd"; systemSupported = sub.packages ? ${system}; in if !systemSupported then {} else {
      sonline0-initrd = sub.packages.${system}.make-sonline0-initrd;
      sonline0-initrd-test = sub.packages.${system}.make-sonline0-initrd-test;
      sonline0-initrd-install = sub.packages.${system}.make-sonline0-initrd-install;
      sonline0-initrd-install-test = sub.packages.${system}.make-sonline0-initrd-install-test;
    })
    // (if system == "x86_64-linux" then { allChecks = pkgs.linkFarmFromDrvs "all-checks" (nixpkgs.lib.attrValues self.checks.${system}); } else {})
    // (if system == "x86_64-linux" then {
      # no way to build this in pure (flake) land so we lie and say that the license was free
      # hm, or maybe there is? `NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#omada-controller-unfree` -> yes :-)
      #omada-controller-unfree = pkgs.callPackage ./pkgs/omada-controller.nix { mongodb = pkgs.mongodb.overrideAttrs (old: { meta = { license.free = true; }; }); };
      omada-controller-unfree = pkgs.callPackage ./pkgs/omada-controller.nix {
        mongodb = nixpkgs-mongodb.legacyPackages.${system}.mongodb;
      };
    } else {})
    )
    // (forDarwinSystems (system: let pkgs = nixpkgs.legacyPackages.${system}; in {
      iproute2mac = pkgs.callPackage ./pkgs/iproute2mac.nix {};
    }));

    apps = forAllSystems (system: {
      gcc-gd32   = { type = "app"; program = "${self.packages.${system}.gcc-gd32}/bin/gcc"; };
      openocd-gd32 = { type = "app"; program = "${self.packages.${system}.openocd-gd32}/bin/openocd"; };
      gdb-gd32   = { type = "app"; program = "${self.packages.${system}.gdb-gd32}/bin/riscv32-none-elf-gdb"; };
      rustc-gd32 = { type = "app"; program = "${self.packages.${system}.rustc-gd32}/bin/rustc"; };
      cargo-gd32 = { type = "app"; program = "${self.packages.${system}.cargo-gd32}/bin/cargo"; };
      nrfjprog   = { type = "app"; program = "${self.packages.${system}.nrfjprog}/bin/nrfjprog"; };
      #apio       = { type = "app"; program = "${self.packages.${system}.apio}/bin/apio"; };
      openups    = { type = "app"; program = "${self.packages.${system}.openups}/bin/openups"; };

      bundle = { type = "app"; program = builtins.toString (with nixpkgs.legacyPackages.${system}; writeShellScript "nix-bundle-routeromen" ''
        if [ -z "$1" ] ; then
          echo "Usage: $0 program" >&2
          echo "  program: $(nix-instantiate --eval -E 'let x = builtins.getFlake "${toString self}"; in builtins.attrNames x.apps.${system}')"
          exit 1
        else
          nix-build -E 'let x = builtins.getFlake "${toString self}"; in x.defaultBundler { system = "${system}"; program = with x.apps.${system}; ('"$1"').program; rsyncable = true; }'
        fi
      ''); };

      nixFlakes = { type = "app"; program = builtins.toString (with nixpkgs.legacyPackages.${system}; writeShellScript "nix-flakes" ''
        exec ${nixFlakes}/bin/nix --experimental-features "nix-command flakes" "$@"
      ''); };

      test2 = { type = "app"; program = builtins.toString (with nixpkgs.legacyPackages.${system}; writeShellScript "test" ''
        echo 2
      ''); };

      nixos-install = { type = "app"; program = "${nixpkgs.legacyPackages.${system}.nixos-install-tools}/bin/nixos-install"; };
    }
    // (let sub = getFlakeForHost "sonline0-initrd"; systemSupported = sub.packages ? ${system}; in if !systemSupported then {} else {
      sonline0-initrd-all = sub.apps.${system}.make-sonline0-initrd-all;
      sonline0-initrd-run-qemu = sub.apps.${system}.run-qemu;
      sonline0-initrd-run-qemu-install = sub.apps.${system}.run-qemu-install;
    })
    ) // forDarwinSystems (system: {
      ip = { type = "app"; program = "${self.packages.${system}.iproute2mac}/bin/ip"; };
    });
    devShells = forAllSystems (system: with self.packages.${system}; with nixpkgs.legacyPackages.${system}; {
      gd32 = mkShell {
        buildInputs = [ gcc-gd32 binutils-gd32 rustc-gd32 cargo-gd32 ] ++ [ gcc lld_11 ];
      };
      purethermal = purethermal.${system}.shell;
      flipperzero = flipperzero.${system}.shell;
    });
    # This doesn't conform to the new API anymore.
    # old: defaultBundler { system = system; program = "${drv}/bin/${name}; }
    # new: defaultBundler.${system} (drv // { name = name; })
    #inherit (nix-bundle) bundlers defaultBundler;
  }) // {
    checks.x86_64-linux = let
      lib = nixpkgs.lib;
      slowPackages = [
        # These build llvm for the target.
        "cargo-gd32"
        "rustc-gd32"
        "flipperzero-firmware"
        # Builds lots of things for armv7.
        "rpibootfiles"
        # Avoid infinite recursion
        "allChecks"
        # fails and I don't want to fix it, right now
        "gdb-gd32"
      ];
    in {
      #host-rockpro64-snowball = nixpkgs.legacyPackages.x86_64-linux.runCommand "drv" { target = self.nixosConfigurations.rockpro64-snowball.config.system.build.toplevel.drvPath; } ''ln -s $target $out'';
    } // (lib.attrsets.removeAttrs self.packages.x86_64-linux slowPackages) // nixpkgs.lib.mapAttrs (_: v: v.config.system.build.toplevel) {
      inherit (self.nixosConfigurations) routeromen c3pbvm hetzner-temp nixosvm orangepi-remoteadmin sonline0;
    };
    checks.aarch64-linux = {
      host-rockpro64-snowball = self.nixosConfigurations.rockpro64-snowball.config.system.build.toplevel;
    } // self.packages.aarch64-linux;
  }); in outputFunction inputs1;
}
