{ pkgs, lib, ... }:

let
  greeter-sway-config = ''
    input * {
      xkb_layout de
      xkb_variant nodeadkeys
      xkb_numlock enable
    }

    exec "${pkgs.greetd.gtkgreet}/bin/gtkgreet --layer-shell --command=sway; swaymsg exit"

    bindsym Mod4+shift+e exec swaynag \
      -t warning \
      -m 'What do you want to do?' \
      -b 'Poweroff' 'systemctl poweroff' \
      -b 'Reboot' 'systemctl reboot'

    exec swayidle -w \
      timeout 30 'swaymsg "output * dpms off"' \
      resume 'swaymsg "output * dpms on"'
  '';
  greeter-sway-config-file = pkgs.writeText "greeter-sway-config" greeter-sway-config;

in
{
  environment.systemPackages = with pkgs; [
    # for greeter manpages
    greetd.greetd
    greetd.gtkgreet
  ];

  programs.sway.enable = true;
  programs.sway.extraPackages = with pkgs; [ swayidle ];

  users.users.greeter = {
    isSystemUser = true;
    home = "/var/run/greeter";
    createHome = true;
    # TODO only apply theming
    dotfiles.profiles = [ "desktop" ];
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "sway --config ${greeter-sway-config-file}";
      };
      initial_session = {
        command = "sway";
        user = "jens";
      };
    };
    restart = false;
  };
}
