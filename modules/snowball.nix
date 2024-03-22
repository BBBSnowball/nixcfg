{ lib, config, modules, ... }:
{
  imports = [ modules.common modules.nixcfg-sync ];

  programs.nvim.defaultEditor = lib.mkDefault (! (config.programs.emacs.defaultEditor or false));

  # slightly lower priority than mkDefault so nixos/modules/hardware/video/hidpi.nix will win if enabled
  console.font = lib.mkOverride 1010 "Lat2-Terminus16";
  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  # That's what current NixOS installer generates when we select a mixed locale.
  i18n.extraLocaleSettings = let locale = "de_DE.UTF-8"; in
  {
    LC_ADDRESS = locale;
    LC_IDENTIFICATION = locale;
    LC_MEASUREMENT = locale;
    LC_MONETARY = locale;
    LC_NAME = locale;
    LC_NUMERIC = locale;
    LC_PAPER = locale;
    LC_TELEPHONE = locale;
    LC_TIME = locale;
  };

  time.timeZone = "Europe/Berlin";
}
