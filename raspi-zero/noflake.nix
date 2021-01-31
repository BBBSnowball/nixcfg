{ nixpkgsPath ? <nixpkgs>, nixpkgs ? import nixpkgsPath {} }:
let x = import ./overlay.nix (nixpkgs // x // { nixpkgsPath = nixpkgsPath; }) nixpkgs; in x
