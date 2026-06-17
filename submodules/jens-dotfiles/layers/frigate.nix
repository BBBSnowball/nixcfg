{ lib, config, pkgs, ... }:
with lib;

let
  configFile = pkgs.writeText "frigate-config.yml" ''
    mqtt:
      host: 10.0.2.1

    cameras:
      pinecube:
        ffmpeg:
          input_args: -avoid_negative_ts make_zero -fflags nobuffer -flags low_delay -strict experimental -fflags +genpts+discardcorrupt -use_wallclock_as_timestamps 1
          output_args:
            rtmp: -c:v libx264 -f flv
          inputs:
            - path: http://192.168.178.67:8080/?action=stream
              roles:
                - detect
                - rtmp
        detect:
          width: 1280
          height: 720
  '';
in {
  virtualisation.oci-containers.containers.frigate = {
    image = "blakeblackshear/frigate:0.9.2-amd64";
    imageFile = pkgs.dockerTools.pullImage {
      imageName = "blakeblackshear/frigate";
      finalImageTag = "0.9.2-amd64";
      imageDigest = "sha256:975104371efe6c4878b25fd14b4bb46f0f9de0543e9413fa968998838eae10ef";
      sha256 = "sha256-JjdumF1g6upzgurWAYWdo22qfPEhXNBb9xwr1wiCI/Y=";
    };
    volumes = [
      "frigate:/media/frigate"
      "${configFile}:/config/config.yml:ro"
      "/etc/localtime:/etc/localtime:ro"
    ];
    environment = {
      FRIGATE_RTSP_PASSWORD = "foobar";
    };
    ports = [
      "5000:5000"
      "1935:1935"
    ];
    extraOptions = [
      "--mount=type=tmpfs,target=/tmp/cache,tmpfs-size=1000000000"
      "--device=/dev/dri/renderD128"
      "--shm-size=64m"
    ];
  };
}
