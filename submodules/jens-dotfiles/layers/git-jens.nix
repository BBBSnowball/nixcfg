{ ... }:
{
  imports = [ ./base.nix ];

  users = {
    users.jens = {
      dotfiles.profiles = [ "git-jens" ];
    };
  };
}

