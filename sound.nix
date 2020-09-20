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
  users.users.root.extraGroups = [ "audio" ];
  users.users.test.extraGroups = [ "audio" ];
  users.users.mpd.extraGroups  = [ "audio" ];

# doesn't work, use `machinectl shell test@` instead of `su - test`
  #security.pam.services.su.startSession = true;

  environment.systemPackages = with pkgs; [
    ncpamixer pulsemixer mpv
    mpc_cli ncmpc
  ];

  networking.firewall.br0.allowedTCPPorts = [
    6600
    ympdPort
  ];

  services.shorewall.rules.mpd = {
    proto = "tcp";
    destPort = [ 6600 ympdPort ];
  };

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
  environment.variables.MPD_HOST = "abc@localhost";

  services.ympd = {
    enable = true;
    webPort = ympdPort;
  };

  sound.mediaKeys.enable = true;
  services.actkbd = {
    enable = true;
    bindings = [
      { keys = [ 165 ]; events = [ "key" ];       command = "${pkgs.mpc_cli}/bin/mpc prev"; }
      { keys = [ 164 ]; events = [ "key" ];       command = "${pkgs.mpc_cli}/bin/mpc toggle"; }
      { keys = [ 163 ]; events = [ "key" ];       command = "${pkgs.mpc_cli}/bin/mpc next"; }
    ];
  };
  systemd.services."actkbd@".environment.MPD_HOST = "abc@localhost";

  # remote has a power button - we don't want it to shutdown this host
  services.logind.extraConfig = ''
    HandlePowerKey=ignore
    HandleSuspendKey=ignore
    HandleHibernateKey=ignore
  '';
  # events:
  # button on remote: "button/power PBTN 00000080 00000000 K"
  # real power button: "button/power PBTN 00000080 00000000" and "button/power LNXPWRBN:00 00000080 00000002"
  #  (The last number increases for each event.)
  services.acpid = {
    enable = true;
    #logEvents = true;
    powerEventCommands = ''
      if [ "$1" == "button/power PBTN 00000080 00000000" ] ; then
        poweroff
      fi
    '';
  };
}
