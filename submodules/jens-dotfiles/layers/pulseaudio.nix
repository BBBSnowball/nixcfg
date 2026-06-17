{ config, lib, pkgs, ... }:
with lib;
let
  pactl-bin = "${pkgs.pulseaudio}/bin/pactl";
in
{
  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    systemWide = true;
    daemon.config = {
      "remixing-produce-lfe" = "yes";
      "remixing-consume-lfe" = "yes";
    };
    tcp = mkIf config.queezle.qnet.enable {
      enable = true;
      # TODO get ip range from config
      anonymousClients.allowedIpRanges = ["10.0.0.0/24"];
    };
  };
  users.users.pulse = {
    extraGroups = [ "bluetooth" ];
  };
  users.groups.bluetooth = {};
  users.groups.pulse-access = {};

  # Open PulseAudio port to qnet
  networking.firewall.interfaces.qnet = mkIf config.queezle.qnet.enable {
    allowedTCPPorts = [ 4713 ];
  };

  environment.systemPackages = with pkgs; [
    pulsemixer
  ];

  # workaround for https://github.com/NixOS/nixpkgs/issues/114399
  system.activationScripts.fix-pulse-permissions = ''
    chmod 755 /run/pulse
  '';


  # Focusrite Scarlett 2i4
  # Sample rate switching (e.g. when starting mumble) results in weird glitches; stereo profile can't be applied.
  # It has to be manually configured instead.
  services.udev.extraRules = ''
    ENV{ID_VENDOR_ID}=="1235", ENV{ID_MODEL_ID}=="8200", ENV{PULSE_IGNORE}="1"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="1235", ATTRS{idProduct}=="8200", TAG+="systemd", ENV{SYSTEMD_WANTS}="scarlett-2i4.service"
  '';
  # Remove if above works
  # SUBSYSTEM=="usb", ACTION=="add", ENV{ID_VENDOR_ID}=="1235", ENV{ID_MODEL_ID}=="8200", RUN+="${scarlett-bin}"

  systemd.services.scarlett-2i4 = {
    restartIfChanged = false;
    after = [ "pulseaudio.service" ];
    script = ''
      ${pactl-bin} load-module module-alsa-card device_id=USB card_name=scarlett card_properties=device.description=Scarlett sink_name=scarlett-sink source_name=scarlett-source format=s32le rate=48000 use_ucm=true

      ${pactl-bin} load-module module-remap-sink sink_name=scarlett-sink-stereo sink_properties=device.description=Scarlett_Stereo master=scarlett-sink channels=2 master_channel_map=left,right remix=no

      ${pactl-bin} set-default-sink scarlett-sink-stereo
      ${pactl-bin} set-default-source scarlett-source
    '';
    unitConfig = {
      Description = "Add Focusrite Scarlett 2i4 to PulseAudio";
    };
    serviceConfig = {
      Type = "simple";
      User = "pulse";
    };
  };
}
