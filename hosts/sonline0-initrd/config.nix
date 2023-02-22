{ lib, config, ... }:
with lib;
{
  options.boot.initrd.testInQemu = mkOption {
    type = types.bool;
    default = false;
  };

  options.boot.initrd.withNix = mkOption {
    type = types.bool;
    default = false;
  };

  options.boot.initrd.nameSuffix = mkOption {
    type = types.str;
    default = false;
  };

  config.boot.initrd.nameSuffix = lib.mkDefault
  (with config.boot.initrd;
    (if withNix then "-install" else "")
  + (if testInQemu then "-test" else ""));
}
