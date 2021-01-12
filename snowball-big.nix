{ lib, config, modules, ... }:
{
  imports = [
    modules.snowball
    modules.emacs
  ];

  programs.emacs.defaultEditor = true;
}
