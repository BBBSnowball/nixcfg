{ pkgs, ... }:

{
  documentation.dev.enable = true;

  environment.systemPackages = with pkgs; [
    man-pages
    posix_man_pages

    # Dictionary (command `trans`)
    translate-shell

    gdb
  ];

  users.users = {
    jens = {
      packages = with pkgs; [ direnv ];
    };

    dev = {
      uid = 1300;
      isNormalUser = true;
      packages = with pkgs; [
      ];
      dotfiles.profiles = [ "kitty" "vscode" "tmux" ];
    };
  };
}
