{ lib, config, ... }:
{
  options = {
    nixpkgs.allowUnfreeByName = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "allow unfree packages with names in this list; incompatible with nixpkgs.config.allowUnfreePredicate";
    };
  };

  config = lib.mkIf (config.nixpkgs.allowUnfreeByName != []) {
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.nixpkgs.allowUnfreeByName;
  };
}
