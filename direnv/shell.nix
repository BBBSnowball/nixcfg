let
  pkgs = import <nixpkgs> {};
  a = import ./shell2.nix;
  b = builtins.readFile ./shell3.txt;
  c = builtins.readFile <nixos-unstable/nixpkgs/pkgs/applications/audio/audacity/default.nix>;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    tpm2-tools python3
  ] ++ (if a c || a b then [pkgs.zsh] else []);

  TEST = 123;
  BLUB = "a''b";
  mode = "path-only";
}
