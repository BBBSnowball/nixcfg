{ pkgs, ... }:
let
  usePipewire = true;
in
{
  hardware.bluetooth.enable = true;

  environment.systemPackages = with pkgs; [
    #blueman -> doesn't work
  ];

  services.pipewire = {
    enable = true;
    pulse.enable = usePipewire;
  };

  hardware.pulseaudio.enable = !usePipewire;  # use Pipewire instead
}
