{ pkgs, lib, ... }:
{
  services.octoprint = {
    enable = true;
    #extraConfig = "";
    plugins = plugins: with plugins; let
      lightcontrols = buildPlugin rec {
        pname = "LightControls";
        version = "0.1.2";
    
        src = pkgs.fetchFromGitHub {
          owner = "RoboMagus";
          repo = "Octoprint-${pname}";
          rev = "${version}";
          sha256 = "sha256-Mn+A3z56HpfwW4QOPnept7eAs2S8TcUIg9hitIOfkFI=";
        };
    
        meta = with lib; {
          description = "Control Lights with OctoPrint";
          homepage = "https://github.com/RoboMagus/OctoPrint-LightControls";
          license = licenses.gpl3;
        };
      };
      draggableFiles = buildPlugin rec {
        pname = "Draggable-Files";
        version = "1.1.1";
    
        src = pkgs.fetchFromGitHub {
          owner = "SanderRonde";
          repo = "Octoprint-${pname}";
          rev = "${version}";
          sha256 = "sha256-x6NCc3bHkRfmSMCrSQ/7FzrKQnTw/Iicfj2XKX0bR7I=";
        };
    
        meta = with lib; {
          description = "Plugin that allows for the dragging of files in the File Manager of OctoPrint";
          homepage = "https://github.com/SanderRonde/Octoprint-Draggable-Files";
        };
      };
      gcodeMacros = buildPlugin rec {
        pname = "GCodeMacros";
        version = "1.1.1";
    
        src = pkgs.fetchFromGitHub {
          owner = "cp2004";
          repo = "Octoprint-${pname}";
          rev = "${version}";
          sha256 = "sha256-Q+PEcLmeE/+zmogwdbmO58ZyrOtgt1A4p+z6O1JSQ28=";
        };
    
        meta = with lib; {
          description = "Create custom G-Code macros for OctoPrint";
          homepage = "https://github.com/cp2004/OctoPrint-GCodeMacros";
          license = licenses.agpl3;
        };
      };
      changeFilament = buildPlugin rec {
        pname = "Change_Filament";
        version = "0.3.2";
    
        src = pkgs.fetchFromGitHub {
          owner = "jim-p";
          repo = "${pname}";
          rev = "${version}";
          sha256 = "sha256-l4ffzXyUUezgMNi9qj2eQWdZMsaNeQZswheoBdwLXDo=";
        };
    
        meta = with lib; {
          description = "Plugin for changing filament for OctoPrint";
          homepage = "https://github.com/jim-p/Change_Filament";
          license = licenses.bsd3;
        };
      };
    in [
      themeify stlviewer
      costestimation
      telegram
      touchui
      #octoklipper
      octoprint-dashboard displaylayerprogress
      #lightcontrols
      draggableFiles
      gcodeMacros
      changeFilament
    ];
  };
  users.users.octoprint.extraGroups = [ "dialout" ];
  services.mjpg-streamer = {
    enable = true;
    # using yuv mode, see https://github.com/jacksonliam/mjpg-streamer/issues/236
    # -> limited to VGA resolution
    #inputPlugin = "input_uvc.so -d /dev/video0 -r 1920x1080 -f 15 -y";
    # This seems to work well enough.
    inputPlugin = "input_uvc.so -d /dev/video0 -r 1280x720 --minimum_size 4096";
  };

  networking.firewall.allowedTCPPorts = [ 5000 5050 ];

  # don't abort a running print, please
  # (NixOS will tell us when a restart is necessary and we can do it at a time of our choosing.)
  systemd.services.octoprint.restartIfChanged = false;
}
