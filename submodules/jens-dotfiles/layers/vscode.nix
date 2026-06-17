{ pkgs, ... }:

let
  extensions = (with pkgs.vscode-extensions; [
    bbenoist.Nix
    alanz.vscode-hie-server
    # ms-vscode-remote
  ]);
  vscode-with-extensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = extensions;
  };
in
{
  environment.systemPackages = with pkgs; [
    #vscode-with-extensions
    vscode
  ];
}
