{ lib, config, modules, ... }:
{
  imports = [
    modules.snowball
    modules.emacs
  ];

  #programs.emacs.defaultEditor = true;

  programs.command-not-found.enable = true;
  documentation.dev.enable = true;
}
