{ config, lib, pkgs, ... }:
with lib;

let
  mkSpotifyd = user: port:
    let
      configFile = pkgs.writeText "spotifyd.conf" ''
        [global]
        username_cmd = "cat $CREDENTIALS_DIRECTORY/user"
        password_cmd = "cat $CREDENTIALS_DIRECTORY/password"
        use_keyring = false
        use_mpris = false
        backend = "pulseaudio"
        device_name = "${config.networking.hostName}"
        bitrate = 320
        cache_path = "/var/cache/spotifyd-${user}"
        # This variable's type will change in v0.4, to a number (instead of string)
        initial_volume = "60"
        zeroconf_port = ${toString port}
        device_type = "a_v_r"
      '';
    in {
      systemd.services."spotifyd-${user}" = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "pulseaudio.service" ];
        description = "spotifyd, a Spotify playing daemon";
        environment.SHELL = "/bin/sh";
        unitConfig = {
          StartLimitBurst = 3;
          StartLimitIntervalSec = "60s";
        };
        serviceConfig = {
          ExecStart = "${pkgs.spotifyd}/bin/spotifyd --no-daemon --config-path ${configFile}";
          Restart = "on-failure";
          RestartSec = 30;
          CacheDirectory = "spotifyd-${user}";
          Environment = [
            "PULSE_SERVER=/run/pulse/native"
          ];

          LoadCredential = [
            "user:/etc/secrets/spotify/${user}/user"
            "password:/etc/secrets/spotify/${user}/password"
          ];

          User = "spotifyd-${user}";
          ProtectSystem = "full";
          ProtectHome = true;
          PrivateDevices = true;
          ProtectProc = "invisible";
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          ProtectKernelLogs = true;
          RestrictSUIDSGID = true;
          RestrictNamespaces = true;
        };
      };
      users.users."spotifyd-${user}" = {
        isSystemUser = true;
        group = "spotifyd-${user}";
        extraGroups = [ "audio" ];
      };
      users.groups."spotifyd-${user}" = {};
    };
in
{
  options.queezle.spotifyd = {
      jens.enable = mkOption {
        type = types.bool;
        default = false;
      };
      k8.enable = mkOption {
        type = types.bool;
        default = false;
      };
  };

  config = mkMerge [
    (mkIf config.queezle.spotifyd.jens.enable (mkSpotifyd "jens" 41234))
    (mkIf config.queezle.spotifyd.k8.enable (mkSpotifyd "k8" 41235))
  ];
}
