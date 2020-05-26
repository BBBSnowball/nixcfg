let
  pkgs = import <nixpkgs> {};
  a = import ./shell2.nix;
  b = builtins.readFile ./shell3.txt;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    tpm2-tools python3
  ] ++ (if a b then [pkgs.zsh] else []);
}
