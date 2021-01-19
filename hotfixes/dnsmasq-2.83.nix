self: super: {
  dnsmasq =
    if super.dnsmasq.name != "dnsmasq-2.82"
    then builtins.trace "hotfix not used for ${super.dnsmasq.name}" super.dnsmasq
    else let
      # see https://github.com/NixOS/nixpkgs/pull/109971
      src = self.fetchurl {
        url = "https://raw.githubusercontent.com/NixOS/nixpkgs/de0429c932b5f7dae2e9da67586f9ce197221594/pkgs/tools/networking/dnsmasq/default.nix";
        sha256 = "sha256-pumxMsl04gk/w8dbBxgIKSmp8h82wLNZ4MMsWfCu6Ms=";
      };
    #in super.callPackage (import src) {};
    in import src { inherit (self) stdenv fetchurl pkgconfig dbus nettle fetchpatch libidn libnetfilter_conntrack; };
}
