#! /bin/sh
exec nix build ".#nixosConfigurations.orangepi-remoteadmin.config.system.build.orangepi-installer" --override-input routeromen/private path:/etc/nixos/hosts/orangepi-remoteadmin/private/data
