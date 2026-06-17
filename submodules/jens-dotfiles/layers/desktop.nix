# Basic desktop functionality (window manager, terminal emulator, browser and a few utilities)
{ pkgs, lib, ... }:

let
  swaylockWithIdle = pkgs.writeScriptBin "swaylock-with-idle" ''
    #!/usr/bin/env zsh

    trap 'qctl set /g815/idle false; swaymsg "output * dpms on"' EXIT INT HUP TERM

    swayidle -w \
      timeout 10 'q system idle; swaymsg "output * dpms off"' \
      resume 'q system not-idle; swaymsg "output * dpms on"' \
      &

    swaylock $@

    kill %1
  '';

  blockPath = ../../desktop/blocks;

in
{
  imports = [
    ./base.nix
    ./greeter.nix
    ./pulseaudio.nix
  ];

  queezle.desktop.enable = true;

  environment.systemPackages = with pkgs; [
    # desktop environment programs
    kitty
    foot
    glxinfo
    gnome3.gnome-disk-utility
    networkmanagerapplet
    wayvnc
    tigervnc
    dfeet
    #vimiv
    mpv-queezle
    wdisplays
    squeekboard
    feh

    # screenshot utilities
    grim
    slurp

    # cursor theme (installed via `home-profiles/desktop/.local/share/icons/default/index.theme`)
    simpleandsoft

    # icon theme (required for e.g. `lutris`)
    gnome3.adwaita-icon-theme

    # soft desktop dependencies
    swaylockWithIdle
    zsh
    mako
    rofi
    qt5.qtwayland
    acpilight
    gammastep
    kanshi
    libnotify
    wl-clipboard
    ddcutil
    pamixer

    # theme
    adwaita-qt

    # qbar block dependencies
    qbar
    python3
    acpi
    perl
    sysstat
    zsh
    bash
    wirelesstools
    lm_sensors
    jq
  ];

  fonts = {
    fonts = with pkgs; [ fira-code pragmatapro ];
    fontconfig.defaultFonts.monospace = [ "PragmataPro Liga" ];
  };

  users = {
    users.jens = {
      packages = with pkgs; [
        q
        chromium
        pavucontrol
        playerctl
        xdg_utils
      ];
      extraGroups = [
        "video"
        "pulse-access"
      ];
      dotfiles.profiles = [ "kitty" "vscode" "desktop" ];
    };
  };

  queezle.sway.enable = true;


  programs.sway.enable = true;
  programs.sway.extraPackages = with pkgs; [ swaylock swayidle xwayland kitty cool-retro-term xorg.xrdb ];
  # QT_QPA_PLATFORM=wayland requires qt5.qtwayland in systemPackages
  programs.sway.extraSessionCommands = ''
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=sway

    export SDL_VIDEODRIVER=wayland

    export MOZ_ENABLE_WAYLAND=1

    # Creates problems with OBS
    #export QT_QPA_PLATFORM=wayland

    export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"

    export QT_STYLE_OVERRIDE=adwaita-dark
  '';
  # Start on tty1 login is disabled because I'm using a display manager
  #environment.loginShellInit = ''
  #  # start sway when logging in on tty1
  #  if [ "$USER" = jens ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ] && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
  #    exec sway &> /run/user/$UID/sway_log
  #  fi
  #'';

  environment.etc."xdg/Trolltech.conf".text = ''
    [Qt]
    style=adwaita-dark
  '';
}
