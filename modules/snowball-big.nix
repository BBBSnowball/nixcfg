{ lib, pkgs, config, modules, ... }:
{
  imports = [
    modules.snowball
    modules.emacs
  ];

  #programs.emacs.defaultEditor = true;

  programs.command-not-found.enable = true;
  documentation.dev.enable = true;

  environment.systemPackages = with pkgs; [
    entr
    unzip
    lshw
    pwgen
    tcpdump
    picocom
    python3
    w3m
    git-annex
    git-revise
  ];

  programs.git.package = pkgs.gitFull;  # provides `git gui`
}
