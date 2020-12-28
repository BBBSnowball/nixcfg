#!/bin/sh
exec nix build path:.#nixosConfigurations.rockpro64.config.system.build.toplevel
