{ lib, config, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
in {
  imports = [
    modules.snowball
    modules.emacs
  ];

  programs.emacs.defaultEditor = true;
}
