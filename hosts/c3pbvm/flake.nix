{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  inputs.flake-compat.follows = "routeromen/flake-compat";
  inputs.routeromen.url = "github:BBBSnowball/nixcfg";
  inputs.routeromen.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgsLetsmeet.url = "github:NixOS/nixpkgs/nixos-23.05";  # edumeet wants NodeJS 16
  inputs.chatgpt-telegram-bot.url = "github:BBBSnowball/chatgpt-telegram-bot";
  inputs.chatgpt-telegram-bot.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, routeromen, ... }@flakeInputs:
    routeromen.lib.mkFlakeForHostConfig "c3pbvm" "x86_64-linux" ./main.nix flakeInputs;
}
