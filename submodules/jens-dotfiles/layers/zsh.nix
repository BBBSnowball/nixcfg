{ pkgs, config, ... }:

let
  promptPath = ../zsh/prompt;

in
{
  environment.systemPackages = with pkgs; [
    neovim-queezle
    w3m
    less
    # required for neovim spellcheck
    aspell
    # used for icat
    notcurses
  ];

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    clock24 = true;
  };

  programs.zsh.enable = true;
  programs.zsh.enableGlobalCompInit = false;

  programs.zsh.promptInit = ''
    if [ "$TERM" != dumb ]
    then
      fpath+=${promptPath}

      source ${promptPath}/load_prompt
    fi
  '';

  environment.shellAliases = {
    ".." = "cd ..";

    # When using w3m as a pager, man pipes manpages into the pager. To get advanced functionality (e.g. man page
    # hyperlinks) w3mman has to be used directly instead.
    #man = "w3mman";

    ls = "ls --color=auto";
    l = "ls -l";
    lh = "ls -lh";
    la = "ls -la";
    lah = "ls -lah";

    icat = "print; ncplayer -k -t0 -q -b pixel -s none";

    # tree configured to ignore .gitignore
    gtree = "${pkgs.tree}/bin/tree --fromfile <(${pkgs.fd}/bin/fd -H -E .git)";

    nix-zsh = "nix-shell --packages zsh --command \"exec zsh\"";

    cal = "cal --monday";

    copy = "xclip -selection c -i";
    paste = "xclip -selection c -o";

    err = "${pkgs.moreutils}/bin/errno $?";

    # Start tmux in a transient scope (a PAM session would be better but this works)
    tmux-new = "systemd-run --scope --user tmux";

    msub = "mosquitto_sub";
    mpub = "mosquitto_pub";

    myip = "drill @resolver1.opendns.com any myip.opendns.com";
    myipv4 = "drill -4 @resolver1.opendns.com any myip.opendns.com";
    myipv6 = "drill -6 @resolver1.opendns.com any myip.opendns.com";

    visual-hostkey = "ssh-keygen -lvf /etc/ssh/ssh_host_ed25519_key.pub";

    starwars="nix-shell -p telnet --run 'telnet towel.blinkenlights.nl'";
  };

  environment.shellInit = ''
    export EDITOR=nvim
    export VISUAL=nvim
    export PAGER=less
    export LS_COLORS='no=00:fi=00:di=34:ow=34;40:ln=35:pi=30;44:so=35;44:do=35;44:bd=33;44:cd=37;44:or=05;37;41:mi=05;37;41:ex=01;31:*.cmd=01;31:*.exe=01;31:*.com=01;31:*.bat=01;31:*.reg=01;31:*.app=01;31:*.txt=32:*.org=32:*.md=32:*.mkd=32:*.h=32:*.c=32:*.C=32:*.cc=32:*.cpp=32:*.cxx=32:*.objc=32:*.sh=32:*.csh=32:*.zsh=32:*.el=32:*.vim=32:*.java=32:*.pl=32:*.pm=32:*.py=32:*.rb=32:*.hs=32:*.php=32:*.htm=32:*.html=32:*.shtml=32:*.erb=32:*.haml=32:*.xml=32:*.rdf=32:*.css=32:*.sass=32:*.scss=32:*.less=32:*.js=32:*.coffee=32:*.man=32:*.0=32:*.1=32:*.2=32:*.3=32:*.4=32:*.5=32:*.6=32:*.7=32:*.8=32:*.9=32:*.l=32:*.n=32:*.p=32:*.pod=32:*.tex=32:*.go=32:*.bmp=33:*.cgm=33:*.dl=33:*.dvi=33:*.emf=33:*.eps=33:*.gif=33:*.jpeg=33:*.jpg=33:*.JPG=33:*.mng=33:*.pbm=33:*.pcx=33:*.pdf=33:*.pgm=33:*.png=33:*.PNG=33:*.ppm=33:*.pps=33:*.ppsx=33:*.ps=33:*.svg=33:*.svgz=33:*.tga=33:*.tif=33:*.tiff=33:*.xbm=33:*.xcf=33:*.xpm=33:*.xwd=33:*.xwd=33:*.yuv=33:*.aac=33:*.au=33:*.flac=33:*.m4a=33:*.mid=33:*.midi=33:*.mka=33:*.mp3=33:*.mpa=33:*.mpeg=33:*.mpg=33:*.ogg=33:*.ra=33:*.wav=33:*.anx=33:*.asf=33:*.avi=33:*.axv=33:*.flc=33:*.fli=33:*.flv=33:*.gl=33:*.m2v=33:*.m4v=33:*.mkv=33:*.mov=33:*.MOV=33:*.mp4=33:*.mp4v=33:*.mpeg=33:*.mpg=33:*.nuv=33:*.ogm=33:*.ogv=33:*.ogx=33:*.qt=33:*.rm=33:*.rmvb=33:*.swf=33:*.vob=33:*.webm=33:*.wmv=33:*.doc=31:*.docx=31:*.rtf=31:*.dot=31:*.dotx=31:*.xls=31:*.xlsx=31:*.ppt=31:*.pptx=31:*.fla=31:*.psd=31:*.7z=1;35:*.apk=1;35:*.arj=1;35:*.bin=1;35:*.bz=1;35:*.bz2=1;35:*.cab=1;35:*.deb=1;35:*.dmg=1;35:*.gem=1;35:*.gz=1;35:*.iso=1;35:*.jar=1;35:*.msi=1;35:*.rar=1;35:*.rpm=1;35:*.tar=1;35:*.tbz=1;35:*.tbz2=1;35:*.tgz=1;35:*.tx=1;35:*.war=1;35:*.xpi=1;35:*.xz=1;35:*.z=1;35:*.Z=1;35:*.zip=1;35:*.ANSI-30-black=30:*.ANSI-01;30-brblack=01;30:*.ANSI-31-red=31:*.ANSI-01;31-brred=01;31:*.ANSI-32-green=32:*.ANSI-01;32-brgreen=01;32:*.ANSI-33-yellow=33:*.ANSI-01;33-bryellow=01;33:*.ANSI-34-blue=34:*.ANSI-01;34-brblue=01;34:*.ANSI-35-magenta=35:*.ANSI-01;35-brmagenta=01;35:*.ANSI-36-cyan=36:*.ANSI-01;36-brcyan=01;36:*.ANSI-37-white=37:*.ANSI-01;37-brwhite=01;37:*.log=01;32:*~=01;32:*#=01;32:*.bak=01;33:*.BAK=01;33:*.old=01;33:*.OLD=01;33:*.org_archive=01;33:*.off=01;33:*.OFF=01;33:*.dist=01;33:*.DIST=01;33:*.orig=01;33:*.ORIG=01;33:*.swp=01;33:*.swo=01;33:*,v=01;33:*.gpg=34:*.gpg=34:*.pgp=34:*.asc=34:*.3des=34:*.aes=34:*.enc=34:*.sqlite=34:'

    # set the default less options
    export LESS='-g -i -M -R -S -w -z-4'

    # export LOCAL_ZSH_COMPLETION_PATH=''${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions
    export LOCAL_ZSH_COMPLETION_PATH=~/.local/zsh-completions
  '';
# FIXME: set the less input preprocessor
#export LESSOPEN="| ${pkgs.lesspipe}/bin/lesspipe.sh %s 2>&-"

  programs.zsh.setOptions = [
    "hist_ignore_all_dups"
    "inc_append_history"
    "hist_fcntl_lock"
    "hist_ignore_space"
    "hist_reduce_blanks"
  ];

  programs.zsh.shellInit = ''
    # Disable new-user configuration
    zsh-newuser-install() { :; }
  '';

  programs.zsh.interactiveShellInit = ''

    fpath+=$LOCAL_ZSH_COMPLETION_PATH

    zstyle ':completion:*' auto-description '%d'
    zstyle ':completion:*' completer _expand _complete _ignored
    zstyle ':completion:*' format '%d'
    zstyle ':completion:*' list-colors "''${(@s.:.)LS_COLORS}"
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
    zstyle ':completion:*' max-errors 0
    zstyle ':completion:*' menu select=1
    zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
    autoload -Uz compinit
    compinit

    if (( $+commands[direnv] ))
    then
      eval "$(direnv hook zsh)"
    fi

    nman() {
      if [[ -n "$1" ]]
      then
        nvim "man://$1"
      else
        nvim "man://$1"
      fi
    }

    # "The time the shell waits, in hundredths of seconds, for another key to be pressed when reading bound multi-character sequences."
    # This is for vim-style multi-letter commands (<f><d> is mapped to <Esc>)
    # TODO verify this can be removed
    #KEYTIMEOUT=20

    HISTSIZE=100000
    SAVEHIST=100000

    unsetopt flow_control

    # Set up fzf for ctrl-t (paste selected paths) and alt-c (cd into selected directory)
    # This also binds ctrl-r, but that binding is reverted later
    source ${pkgs.fzf}/share/fzf/key-bindings.zsh

    # bind ctrl-r and ctrl-s to perform emacs-style history search
    bindkey '^R' history-incremental-search-backward
    bindkey '^S' history-incremental-search-forward

    # Shift-Tab reverse tab through completions
    bindkey '^[[Z' reverse-menu-complete

    # F1 to view man pages
    autoload -Uz run-help
    autoload -Uz run-help-sudo
    autoload -Uz run-help-git
    autoload -Uz run-help-openssl
    bindkey '^[OP' run-help

    # edit command line using $VISUAL (or $EDITOR)
    # bound to ctrl-x-ctrl-e (common shell behaviour) and alt-v (faster shortcut)
    zle -N edit-command-line
    autoload -Uz edit-command-line
    bindkey '\ev' edit-command-line
    bindkey '^X^E' edit-command-line

    # pos1, end, ctrl+arrow word navigation
    bindkey '^[[H' beginning-of-line
    bindkey '^[[F' end-of-line
    bindkey '^[[1;5D' emacs-backward-word
    bindkey '^[[1;5C' emacs-forward-word

    # vi mode
    bindkey -v
    #bindkey 'fd' vi-cmd-mode
    # backspace
    bindkey '^?' backward-delete-char
    # delete key
    bindkey '^[[3~' delete-char

    # ctrl-j, ctrl-k, alt-p, alt-n: search for commands starting with the current input
    bindkey '\ep' history-search-backward
    bindkey '^K' history-search-backward
    bindkey '\en' history-search-forward
    bindkey '^J' history-search-forward
    # alt-enter: insert newline without running command
    bindkey -M viins '\e\r' self-insert-unmeta

    # ctrl-h, ctrl-w, ctrl-? for char and word deletion (standard behavior)
    bindkey '^H' backward-delete-char
    bindkey '^W' backward-kill-word
    bindkey '^U' backward-kill-line

    # ctrl-p, ctrl-n for history navigation (standard behavior)
    bindkey '^P' up-history
    bindkey '^N' down-history

    # bind ctrl-a and ctrl-e to move to beginning/end of line
    bindkey '^a' beginning-of-line
    bindkey '^e' end-of-line

    # alt-backspace to kill backwards to the next '/'
    backward-kill-dir () {
        local WORDCHARS=''${WORDCHARS/\/}
        zle backward-kill-word
    }
    zle -N backward-kill-dir
    bindkey '^[^?' backward-kill-dir


    if [[ -n $terminfo[Ss] ]]
    then
      _set_bar_cursor_sequence=$(echoti Ss 6)
      _set_block_cursor_sequence=$(echoti Ss 2)
    elif [[ $TERM = xterm-kitty || "$TERM" = screen* ]]
    then
      # For some reason kitty does not announce it's Ss/Se capabilities?
      # TERM=screen might be tmux which has the capability or might be a screen which ignores these escapes
      _set_bar_cursor_sequence="\e[6 q"
      _set_block_cursor_sequence="\e[2 q"
    else
      _set_bar_cursor_sequence=""
      _set_block_cursor_sequence=""
    fi

    set-bar-cursor () {
      print -n $_set_bar_cursor_sequence
    }
    set-block-cursor() {
      print -n $_set_block_cursor_sequence
    }


    # change cursor on vi mode switch
    zle-keymap-select() {
      # FIXME: Activating vi-command-mode (typing ":" in vicmd-keymap) results in incorrect bar cursor
      if [ $KEYMAP = vicmd ]; then
        # vi command mode
        set-block-cursor
      else
        set-bar-cursor
      fi
      zle reset-prompt
      zle -R
    }
    zle -N zle-keymap-select

    # runs before executing a command
    preexec() {
      set-block-cursor
    }

    # runs before new prompt
    precmd(){
      # change cursor to bar before new prompt
      set-bar-cursor
    }

    # required for osc7_cwd
    _urlencode() {
      local length="''${#1}"
      for (( i = 0; i < length; i++ )); do
        local c="''${1:$i:1}"
        case $c in
          %) printf '%%%02X' "'$c" ;;
          *) printf "%s" "$c" ;;
        esac
      done
    }

    # Emits a OSC 7 escape sequence
    # OSC 7 is used by foot to open terminals with the CWD
    osc7_cwd() {
      printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$(_urlencode "$PWD")"
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook -Uz chpwd osc7_cwd

    # use cd tab completion without cdpath if that gives a result
    _cd_try_without_cdpath () {
      CDPATH= _cd "$@" || _cd "$@"
    }
    compdef _cd_try_without_cdpath cd pushd

    # colored man output
    man() {
      LESS_TERMCAP_md=$'\e[01;31m' \
      LESS_TERMCAP_me=$'\e[0m' \
      LESS_TERMCAP_se=$'\e[0m' \
      LESS_TERMCAP_so=$'\e[01;44;33m' \
      LESS_TERMCAP_ue=$'\e[0m' \
      LESS_TERMCAP_us=$'\e[01;32m' \
      command man "$@"
    }

    # submit file/stdin to pastebin, optionally signing it
    pastebin () {
        local -r pastebin='https://0x0.st'

        if [ "$1" = '--sign' ]; then
            local -r filter='gpg --clearsign --output -'
            shift
        else
            local -r filter='cat'
        fi

        if [ -n "$1" ]; then
            local -r file="$1"
        else
            local -r file='-'
        fi

        $filter "$file" | curl -F'file=@-' "$pastebin"
    }

    cd () {
      if [[ $# != 1 || -z $1 || -d $1 || $1 == "-" ]] {
        builtin cd $@
      } elif (( $+commands[$1] )) {
        builtin cd ''${1:c:A:h}
      } elif [[ -e $1 ]] {
        builtin cd ''${1:h}
      } else {
        builtin cd $1
      }
    }

    tmp () (
      readonly tmpdir=$(mktemp -d ''${1:-})
      [[ -z $tmpdir ]] && exit 1
      TRAPEXIT() {
        rm -rf $tmpdir
      }
      cd $tmpdir
      zsh -is
    )
  '';
}
