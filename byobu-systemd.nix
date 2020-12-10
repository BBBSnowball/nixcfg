{ pkgs, lib }:
let
  byobu-systemd = pkgs.writeShellScriptBin "byobu" ''
    [ -r "$HOME/.$PKG/backend" ] && . "$HOME/.$PKG/backend"
    if [ "$#" = "0" -a "$BYOBU_BACKEND" == "tmux" ] && ! tmux has-session -t default 2>/dev/null; then
      #systemctl --user byobu-tmux@default.service
      systemd-run --unit=byobu-tmux -p Type=forking ${pkgs.byobu}/bin/byobu new-session -d -s default
    fi
    exec ${pkgs.byobu}/bin/byobu "$@"
  '';
in
{
  environment.systemPackages = lib.mkBefore [ byobu-systemd ];
  #systemd.user.service.byobu-tmux = {
  #  TODO
  #  byobu new-session -d -s %i
  #};
}
