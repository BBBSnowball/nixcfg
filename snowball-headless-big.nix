{ lib, config, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
in {
  imports = [ modules.snowball-big modules.snowball-headless ];
}
