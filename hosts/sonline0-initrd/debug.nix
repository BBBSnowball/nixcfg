{ lib, ... }:
with lib;
{
  options.boot.initrd.debugInQemu = mkOption {
    type = types.bool;
    default = false;
  };
}
