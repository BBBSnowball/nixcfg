{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # https://develop.spacemacs.org/layers/+lang/rust/README.html
    cargo cargo-edit cargo-audit cargo-c rustfmt clippy
  ];
}
