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
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  hardware.pulseaudio.enable = !usePipewire;  # use Pipewire instead
  #sound.enable = !usePipewire;                # use Pipewire's ALSA emulation
}
