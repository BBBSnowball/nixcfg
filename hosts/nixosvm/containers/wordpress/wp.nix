{ lib, callPackage, ... }:
lib.recurseIntoAttrs (
  callPackage ./wp4nix.nix {
    plugins = lib.importJSON ./plugins.json;
    themes = lib.importJSON ./themes.json;
    #languages = lib.importJSON ./languages.json;
    languages = {};
  }
)
