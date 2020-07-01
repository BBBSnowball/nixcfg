{ config, pkgs, lib, ... }:
let
  ympdPort = 6680;
in {
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  # see https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/SystemWide/
  hardware.pulseaudio.systemWide = true;
  #hardware.bluetooth.enable = true;

  #NOTE user must be in audio group

  # doesn't work, use `machinectl shell test@` instead of `su - test`
  #security.pam.services.su.startSession = true;

  environment.systemPackages = with pkgs; [
    ncpamixer pulsemixer mpv
    mpc_cli ncmpc
  ];

  networking.firewall.allowedTCPPorts = [
    6600
    ympdPort
  ];

  # see https://wiki.archlinux.org/index.php/Music_Player_Daemon/Tips_and_tricks
  services.mpd = {
    enable = true;
    network.listenAddress = "any";
    extraConfig = ''
      restore_paused "yes"
      audio_output {
        type  "pulse"
        name  "MPD"
        mixer_type "none"
      }
      password "abc@read,add,control,admin"
    '';
  };
  sound.extraConfig = ''
    #defaults.pcm.dmix.rate 44100 # Force 44.1 KHz
    #defaults.pcm.dmix.format S16_LE # Force 16 bits
  '';
  users.users.mpd.extraGroups = [ "audio" ];
  environment.variables.MPD_HOST = "abc@localhost";

  services.ympd = {
    enable = true;
    webPort = ympdPort;
  };

  sound.mediaKeys.enable = true;
  services.actkbd = {
    enable = true;
    #bindings = [
    #  #TODO
    #];
  };
}