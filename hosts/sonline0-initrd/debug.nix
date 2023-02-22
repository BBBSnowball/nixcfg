{ lib, ... }:
with lib;
{
  options.boot.initrd.testInQemu = mkOption {
    type = types.bool;
    default = false;
  };
}
