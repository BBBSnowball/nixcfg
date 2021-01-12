{ lib, config, modules, ... }:
{
  imports = [ modules.common ];

  programs.nvim.defaultEditor = lib.mkDefault (! (config.programs.emacs.defaultEditor or false));

  console.font = lib.mkDefault "Lat2-Terminus16";
  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "Europe/Berlin";
}
