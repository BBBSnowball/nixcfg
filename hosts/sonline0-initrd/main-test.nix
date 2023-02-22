{ withFlakeInputs, ... }:
{
  imports = [ (withFlakeInputs ./main.nix) ];
  boot.initrd.testInQemu = true;
}
