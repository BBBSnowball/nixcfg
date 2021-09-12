{ lib, config, modules, ... }:
{
  imports = [ modules.common ];

  programs.nvim.defaultEditor = lib.mkDefault (! (config.programs.emacs.defaultEditor or false));

  # slightly lower priority than mkDefault so nixos/modules/hardware/video/hidpi.nix will win if enabled
  console.font = lib.mkOverride 1010 "Lat2-Terminus16";
  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "Europe/Berlin";
}
