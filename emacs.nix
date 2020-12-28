{ pkgs, ... }:
{
  services.emacs.enable = true;
  #services.emacs.package = pkgs.emacs-nox;
  services.emacs.package = ((pkgs.emacsPackagesNgGen pkgs.emacs-nox).emacsWithPackages (epkgs: [
    #epkgs.emacs-libvterm
    epkgs.vterm
  ]));

  programs.bash.interactiveShellInit = ''
    # nix-shell is setting TEMPDIR/TEMP/TMPDIR/TMP to $XDG_RUNTIME_DIR. I strongly object
    # to this but it is quite unlikely that this will be fixed soon.
    # see https://github.com/NixOS/nix/issues/2957
    # This causes problems for emacs because it looks for the server socket in /tmp or
    # /run/user depending on whether we are in nix-shell.
    #
    # However, the emacs server socket actually should be in $XDG_RUNTIME_DIR so let's always
    # put it there. Unfortunately, EMACS_SERVER_FILE is for TCP connections so we have to use
    # a non-standard variable and pass it to emacsclient - see above.
    EMACS_SERVER_SOCKET="$XDG_RUNTIME_DIR/emacs$UID/server"

    alias e='emacsclient --create-frame --tty -s $EMACS_SERVER_SOCKET --alternate-editor=\"\"'
    export EDITOR="emacsclient -t -s $EMACS_SERVER_SOCKET"
  '';
}
