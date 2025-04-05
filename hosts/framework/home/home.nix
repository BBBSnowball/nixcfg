{ lib, privateForHost, ... }:
let
  inherit (privateForHost) firefoxProfileName;
  #firefoxProfilePath = "${lib.linux.configPath}/${firefoxProfileName}";
  firefoxProfilePath = ".mozilla/firefox/${firefoxProfileName}";
in
{
  home.stateVersion = "24.11";

  home.file = {
    # disable tab bar
    # similar to programs.firefox.profiles.<name>.userChrome (but I have no clue whether programs.firefox.enable would do additional things)
    "${firefoxProfilePath}/chrome/userChrome.css".text = ''
      #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar > .toolbar-items {
        opacity: 0;
        pointer-events: none;
      }
      
      #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
          visibility: collapse !important;
      }
    '';
  };
}
