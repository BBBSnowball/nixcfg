{ pkgs, config, ... }:
{
  imports = [
    ./desktop.nix
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  # modprobe v4l2loopback video_nr=42 card_label="IP Webcam"
  # ffmpeg -i http://10.0.2.5:8080/video -vf format=yuv420p -f v4l2 /dev/video1

  environment.systemPackages = with pkgs; [
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        wlrobs
      ];
    })
  ];
}
