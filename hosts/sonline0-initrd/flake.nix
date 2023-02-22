# nix run --override-input routeromen ../.. --override-input routeromen/private path:/etc/nixos/hosts/sonline0/private/data/ .#make-sonline0-initrd
# nix run --override-input routeromen ../.. --override-input routeromen/private path:/etc/nixos/hosts/sonline0/private/data/ .#make-sonline0-initrd-test
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
  let
    normal = routeromen.lib.mkFlakeForHostConfig "sonline0" "x86_64-linux" ./main.nix flakeInputs;
    test = routeromen.lib.mkFlakeForHostConfig "sonline0" "x86_64-linux" ./main-test.nix flakeInputs;

    pkgs = nixpkgs.legacyPackages.x86_64-linux;

    ourPkgs = cfg: rec {
      inherit (cfg.config.system.build)
        kernel
        initialRamdisk
        initialRamdiskSecretAppender;
  
      make-sonline0-initrd = pkgs.writeShellScriptBin "mkinitrd" ''
        set -e
        umask 077
        dir=${if cfg.config.boot.initrd.testInQemu then "result-initrd-test" else "result-initrd"}
        test=${if cfg.config.boot.initrd.testInQemu then "1" else "0"}
        mkdir -p $dir
        rm -f $dir/{bzImage,initrd,initrd.tmp}
        cp -L ${kernel}/bzImage $dir/bzImage
        cp -L ${initialRamdisk}/initrd $dir/initrd.tmp
        chmod +w $dir/initrd.tmp
        ${initialRamdiskSecretAppender}/bin/append-initrd-secrets $dir/initrd.tmp
        mv $dir/initrd.tmp $dir/initrd

        ( echo -n "initrd "; cat /etc/nixos/secret/by-host/sonline0-initrd/ssh_host_rsa_key.pub ) >$dir/known_hosts.tmp
        mv $dir/known_hosts.tmp $dir/known_hosts

        ssh_config="$(cat ${./ssh_config})"
        pattern=./known_hosts
        replacement=$(readlink -f "$dir")/known_hosts
        ssh_config=''${ssh_config//$pattern/$replacement}
        ( echo "$ssh_config"
          if [ "$test" == "0" ] ; then
            source /etc/nixos/secret/by-host/sonline0-initrd/secretenv
            if [ -n "$ipv4" ] ; then
              echo "Host initrd"
              echo "  HostName $ipv4"
              echo -n "  Port "; 
              nix eval --impure --expr '(import /etc/nixos/hosts/sonline0/private/data/by-host/sonline0/initrd.nix { testInQemu = false; }).port'
            fi
            if [ -n "$ipv6" ] ; then
              echo "Host initrd6"
              echo "  HostName $ipv6"
              echo -n "  Port "; 
              nix eval --impure --expr '(import /etc/nixos/hosts/sonline0/private/data/by-host/sonline0/initrd.nix { testInQemu = false; }).port'
            fi
          fi
        ) >$dir/ssh_config.tmp
        mv $dir/ssh_config.tmp $dir/ssh_config

        echo "initrd has been generated at $dir/initrd"
        echo "connect with: ssh -F $dir/ssh_config -i ~/.ssh/id_rsa initrd  # or initrd6 or initrd-test"
      '';
    };

    addSuffix = suffix: nixpkgs.lib.mapAttrs' (k: nixpkgs.lib.nameValuePair (k+suffix));
    # The check would throw an exception because they don't have any root filesystem or bootloader config.
    # Therefore, let's omit them, for now.
    omitNixosConfigurations = xs: builtins.removeAttrs xs ["nixosConfigurations"];
  in omitNixosConfigurations (normal // rec {
    #nixosConfigurations.sonline0-initrd = normal.nixosConfigurations.sonline0;
    #nixosConfigurations.sonline0-initrd-test = test.nixosConfigurations.sonline0;

    packages.x86_64-linux =
      (addSuffix "-test" (ourPkgs test.nixosConfigurations.sonline0))
      // (ourPkgs normal.nixosConfigurations.sonline0)
      // { default = self.packages.x86_64-linux.make-sonline0-initrd; };

    apps.x86_64-linux = {
      # make-sonline0-initrd and make-sonline0-initrd-test can be run via packages so we don't add them here.
      # make-sonline0-initrd is the default.
      test = {
        type = "app";
        program = (pkgs.writeShellScript "test-sonline0-initrd" ''
          set -xe
          ${packages.x86_64-linux.make-sonline0-initrd-test}/bin/mkinitrd
          ${./test.sh} result-initrd-test
        '').outPath;
      };
    };
  });
# then: scp result-initrd/{bzImage,initrd} the-server:
#       ssh the-server kexec --load --initrd=initrd --reuse-cmdline bzImage
#       ssh the-server kexec --force --exec
}
