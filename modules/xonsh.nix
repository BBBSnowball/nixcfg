{ pkgs, ... }:
let
  xontrib-fzf-widgets = pkgs.fetchFromGitHub {
    owner = "laloch";
    repo = "xontrib-fzf-widgets";
    rev = "v0.0.4";
    hash = "sha256-lz0oiQSLCIQbnoQUi+NJwX82SbUvXJ+3dEsSbOb20q4=";
  };
  xontrib-prompt-bar = pkgs.fetchFromGitHub {
    owner = "anki-code";
    repo = "xontrib-prompt-bar";
    rev = "0.5.2";
    hash = "sha256-4lsu+5SYJxPT1+9i8s1C0W7xPYRBocgAu8uQkNjubT8=";
  };
  # break colors of prompt and doesn't work so well, e.g. switch to normal mode is not displayed immediately
  xontrib-prompt-vi-mode = pkgs.fetchFromGitHub {
    owner = "t184256";
    repo = "xontrib-prompt-vi-mode";
    rev = "ed31f520fe4a62f6992e8d9181fc2ed018161015";  #v0.1.3 but no tag
    hash = "sha256-9xCCfM1Rt0ESa8Bsq+CnImpGoS0zCFtVesJfB91+/7Q=";
  };
  tcg = pkgs.fetchFromGitHub {
    owner = "zasdfgbnm";
    repo = "tcg";
    rev = "c16434e7b6df4d85267585868194b9ef7f59a646";  # newest one with useful changes for xonsh
    hash = "sha256-2I5AToQ9JKs0sCXJliJDG+ArwyIDW/BKkZdSGAJHlLs=";
  };
  xontribs = [
    xontrib-fzf-widgets
    xontrib-prompt-bar
    xontrib-prompt-vi-mode
    #"${tcg}/shells/xonsh"
  ];
in
{
  programs.xonsh.enable = true;
  #programs.xonsh.package = ...;

  programs.xonsh.config = ''
    # https://github.com/anki-code/xontrib-rc-awesome/blob/main/xontrib/rc_awesome.xsh
    $XONSH_HISTORY_BACKEND = 'sqlite'
    $AUTO_CD = True
    aliases['md'] = 'mkdir -p $arg0 && cd $arg0'

    $BASH_COMPLETIONS = ("${pkgs.bash-completion}/share/bash-completion/bash_completion",)
    $COMPETIONS_IN_THREAD = True
    $ENABLE_ASYNC_PROMPT = True
    $HISTCONTROL = "ignoredups,ignorespace"
    #$MOUSE_SUPPORT = True  # break selection of text by mouse
    #$XONSH_COLOR_STYLE = "monokai"
    $XONSH_HISTORY_SIZE = (1000000000, 'commands')
    # remove "xonsh" from title
    $TITLE = '{current_job:{} | }{user}@{hostname}: {cwd}'

    import sys
    #sys.path.append("${xontrib-fzf-widgets}")
    sys.path.extend(${builtins.toJSON xontribs})
    xontrib load abbrevs coreutils fzf-widgets pdb prompt_ret_code

    abbrevs["gst"] = "git status"

    # https://github.com/laloch/xontrib-fzf-widgets
    $fzf_history_binding = "c-r"  # Ctrl+R
    $fzf_ssh_binding = "c-s"      # Ctrl+S
    $fzf_file_binding = "c-t"      # Ctrl+T
    $fzf_dir_binding = "c-g"      # Ctrl+G
    $fzf_find_command = "fd"
    $fzf_find_dirs_command = "fd -t d"

    # https://xon.sh/xonshrc.html#make-json-data-directly-pastable
    # -> wins over `false` command - not good.
    #import builtins
    #builtins.true = True
    #builtins.false = False
    #builtins.null = None

    $VI_MODE = True

    # use ctrl-o to enter Vi navigation mode (not only temporary)
    # https://xon.sh/tutorial_ptk.html
    @events.on_ptk_create
    def my_vi_keybindings(bindings, **kw):
      from prompt_toolkit.keys import Keys
      from prompt_toolkit.key_binding.vi_state import InputMode

      @bindings.add(Keys.ControlO)
      def _to_navigation(event) -> None:
          buffer = event.current_buffer
          vi_state = event.app.vi_state
  
          if vi_state.input_mode in (InputMode.INSERT, InputMode.REPLACE):
              buffer.cursor_position += buffer.document.get_cursor_left_position()
  
          vi_state.input_mode = InputMode.NAVIGATION

    from datetime import timedelta
    def _cmd_duration():
      if len(XSH.history.tss) == 0:
        return ""
      t = XSH.history.tss[-1]
      d = t[1] - t[0]
      if d >= 3:
        return "{BOLD_WHITE}[%s]" % timedelta(seconds=round(d))
    $PROMPT_FIELDS["tss"] = _cmd_duration
    if "{BOLD_BLUE}{ret_code_color}" in $PROMPT:
      $PROMPT = $PROMPT.replace("{BOLD_BLUE}{ret_code_color}", "{tss}{BOLD_BLUE}{ret_code_color}")
    else:
      $PROMPT = $PROMPT.replace("{prompt_end}{RESET}", "{tss}{prompt_end}{RESET}")

    # do this late so we don't disable traceback errors in this file
    #$XONSH_TRACEBACK_LOGFILE = f"{$XONSH_DATA_DIR}/traceback.txt"
    #aliases['tb'] = 'cat $XONSH_TRACEBACK_LOGFILE; rm $XONSH_TRACEBACK_LOGFILE'
    # xog does the same but better
    xontrib load xog
    aliases['tb'] = 'xog'
    $XONSH_SHOW_TRACEBACK = False
  '';

  # nix puts the config at /etc/xonshrc but if we want to test xonsh in a virtualenv,
  # it will look at /etc/xonsh/xonshrc
  environment.etc."xonsh/xonshrc".source = "/etc/xonshrc";

  environment.systemPackages = with pkgs; [
    fzf ranger wl-clipboard fd broot
    #onefetch
  ];
}
