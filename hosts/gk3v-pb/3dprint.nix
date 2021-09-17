{ pkgs, ... }:
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
          description = "Plugin that allows for the dragging of files in the File Manager of OctoPrint";
          homepage = "https://github.com/jim-p/Change_Filament";
        };
      };
    in [
      themeify stlviewer
      #lightcontrols
      draggableFiles
      changeFilament
    ];
  };
  users.users.octoprint.extraGroups = [ "dialout" ];
  services.mjpg-streamer = {
    enable = true;
    # using yuv mode, see https://github.com/jacksonliam/mjpg-streamer/issues/236
    inputPlugin = "input_uvc.so -d /dev/video0 -r 1920x1080 -f 15 -y";
  };
}
