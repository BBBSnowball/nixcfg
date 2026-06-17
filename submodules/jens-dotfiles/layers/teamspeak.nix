{ pkgs, ... }:

{
  imports = [
    # remove once multi-user audio works
    ./steam.nix
  ];

  # remove once multi-user audio works
  users.users.steam = {
    packages = with pkgs; [
      teamspeak_client
    ];
  };

  users.users.teamspeak = {
    uid = 1200;
    isNormalUser = true;
    packages = with pkgs; [
      teamspeak_client
    ];
    extraGroups = [
      "audio"
      "pulse-access"
    ];
  };
}
