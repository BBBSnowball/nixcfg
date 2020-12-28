{ config, pkgs, ... }@args:
let
  jens-dotfiles = args.jens-dotfiles or ./submodules/jens-dotfiles;
  jens = import "${jens-dotfiles}/layers/zsh.nix" { inherit pkgs; };
in jens // {
  programs = jens.programs // {
    zsh = jens.programs.zsh // {
      #promptInit = ''
      #  export PURE_GIT_PULL=0
      #'' + jens.programs.zsh.promptInit;
      promptInit = ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      '';

      interactiveShellInit = builtins.replaceStrings ["bindkey 'fd' vi-cmd-mode"] ["bindkey 'jk' vi-cmd-mode"] jens.programs.zsh.interactiveShellInit
        + ''
          zstyle ':completion:*' matcher-list "" '+m:{a-z}={A-Z}' '+m:{A-Z}={a-z}'

          # use the vi navigation keys in menu completion
          # see https://unix.stackexchange.com/questions/313093/can-i-navigate-zshs-tab-completion-menu-with-vi-like-hjkl-keys
          zmodload zsh/complist
          bindkey -M menuselect '^h' vi-backward-char
          bindkey -M menuselect '^k' vi-up-line-or-history
          bindkey -M menuselect '^l' vi-forward-char
          bindkey -M menuselect '^j' vi-down-line-or-history

          bindkey '^k' up-history
          bindkey '^j' down-history

          # do again to make it actually work
          bindkey -v
        '';

      ohMyZsh = {
        enable = false;
        #theme = "powerlevel10k";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    fd lf
  ];
}
