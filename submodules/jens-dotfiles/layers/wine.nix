{ lib, pkgs, ... }:

{
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.pulseaudio.support32Bit = true;

  # Required for lutris until it is replaced
  nixpkgs.config.permittedInsecurePackages = [
    "p7zip-16.02"
  ];

  # Configure xfce for applications that might require apis that are not yet available under wayland (I'm not aware of any right now).
  # Use `systemctl start display-manager.service` to start xorg.
  #services.xserver.enable = true;
  #services.xserver.desktopManager.xfce.enable = true;
  #services.xserver.autorun = false;

  users.users.wine = {
    isNormalUser = true;
    uid = 1101;
    passwordFile = "/etc/secrets/passwords/steam";
    extraGroups = [ "audio" "pulse-access" ];
    packages = with pkgs; [
      (wine.override {
        wineBuild = "wineWow";
        wineRelease = "stable";
        pulseaudioSupport = true;
        pngSupport = true;
        jpegSupport = true;
        colorManagementSupport = true;
        openalSupport = true;
        tiffSupport = true;
        vaSupport = true;
        fontconfigSupport = true;
        alsaSupport = true;
        xineramaSupport = true;
        vulkanSupport = true;
        sdlSupport = true;
        gstreamerSupport = true;
        openclSupport = true;
        openglSupport = true;
      })
      lutris
      steam-run-native
    ];
  };

  environment.systemPackages = with pkgs; [
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
  ];
}
