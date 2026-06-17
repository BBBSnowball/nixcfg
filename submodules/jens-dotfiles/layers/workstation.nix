{ pkgs, ... }:

{
  imports = [
    ./desktop.nix
    ./dev.nix
    #./vscode.nix
  ];

  environment.systemPackages = with pkgs; [
    virtmanager
    keepassxc

    tdesktop
    spotify
    gimp
    mumble
    godot
  ];


  users.users.adobe = {
    isNormalUser = true;
    uid = 1202;
    passwordFile = "/etc/secrets/passwords/jens";
    extraGroups = [
    ];
    packages = [
      #pkgs.adobe-reader
    ];
  };

}

