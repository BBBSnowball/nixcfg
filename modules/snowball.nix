{ lib, config, modules, ... }:
{
  imports = [ modules.common ];

  programs.nvim.defaultEditor = lib.mkDefault (! (config.programs.emacs.defaultEditor or false));

  # slightly lower priority than mkDefault so nixos/modules/hardware/video/hidpi.nix will win if enabled
  console.font = lib.mkOverride 1010 "Lat2-Terminus16";
  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "Europe/Berlin";

  # https://github.com/NixOS/nixpkgs/pull/156750
  # https://www.bleepingcomputer.com/news/security/linux-system-service-bug-gives-root-on-all-major-distros-exploit-released/
  # Not that I really need too many reasons to not enable polkit unless there is a good reason for it but this is plenty ^^
  security.polkit.enable = false; # !!!!!
}
