{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (pkgs.python3.withPackages (p: with p; [ ipython ]))
  ];
}