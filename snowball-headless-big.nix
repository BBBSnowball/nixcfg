{ lib, config, modules, ... }:
{
  imports = [ modules.snowball-big modules.snowball-headless ];
}
