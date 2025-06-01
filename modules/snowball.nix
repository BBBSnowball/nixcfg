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
    # I like decimal point instead of comma, so let's keep numbers in en_US locale.
    #LC_NUMERIC = locale;
    LC_PAPER = locale;
    LC_TELEPHONE = locale;
    #LC_TIME = locale;
    # en_DK has ISO date format. Nice!
    # see https://groups.google.com/g/linux.debian.user/c/aYHxiH5jVl4
    LC_TIME = "en_DK.UTF-8";
  };

  time.timeZone = "Europe/Berlin";

  programs.bash.shellAliases.cdd = let
    dirs = [
      "/etc/nixos"
      "/etc/nixos/hosts/*/private"
      "/etc/nixos/flake"
      "/etc/nixos/flake/hosts/*"
      "/etc/nixos/secret"
      "/etc/nixos/secret_local"
      "/etc/nixos/flake/hosts/nixosvm/containers"
      "/etc/nixos/flake/hosts/nixosvm/containers/*"
    ];
  in ''cd "$(ls -1d ${lib.concatStringsSep " " dirs} | fzf)"'';
}
