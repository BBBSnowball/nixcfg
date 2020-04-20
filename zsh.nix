{ config, pkgs, ... }:
let
  jens = import ./submodules/jens-dotfiles/layers/zsh.nix { inherit pkgs; };
in jens // {
  programs = jens.programs // {
    zsh = jens.programs.zsh // {
      promptInit = ''
        export PURE_GIT_PULL=0
      '' + jens.programs.zsh.promptInit;

      interactiveShellInit = builtins.replaceStrings ["bindkey 'fd' vi-cmd-mode"] ["bindkey 'jk' vi-cmd-mode"] jens.programs.zsh.interactiveShellInit
        + ''
          # blub
        '';
    };
  };

  environment.systemPackages = with pkgs; [
    fd lf
  ];
}
