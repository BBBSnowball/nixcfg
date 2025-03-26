{ lib, pkgs, ... }:
let
  ours = import ./inkscape-silhouette-pkg.nix { inherit pkgs; };

  # sendto_silhouette.py is a wrapped shell script (for nixpkgs), so don't run it with Python.
  # We have to keep the previous value for dry_run mode because that is used by the tests.
  silhouette = pkgs.inkscape-extensions.silhouette.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace silhouette_multi.py \
        --replace-fail 'command += " sendto_silhouette.py"' 'command = "<PYTHON> sendto_silhouette.py" if self.options.dry_run else "./sendto_silhouette.py"'
    '';
  });
in
{
  # output of Inkscape plugin but doesn't really match the VID/PID that we want? (1d6b,0003) (27c6,609c) (8087,0032) (1d6b,0002) (1d6b,0003) (1d6b,0002)
  # -> Actually, Silhouette device is recognized as a printer class and udev rules from hplib assign it to group `lp`.
  services.udev.extraRules = lib.mkIf false ''
    # based on https://github.com/fablabnbg/inkscape-silhouette/blob/main/silhouette-udev.rules
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="1139", GROUP="dialout", ENV{silhouette_cameo4pro}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="1138", GROUP="dialout", ENV{silhouette_cameo4plus}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="1137", GROUP="dialout", ENV{silhouette_cameo4}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="112f", GROUP="dialout", ENV{silhouette_cameo3}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="112b", GROUP="dialout", ENV{silhouette_cameo2}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="1121", GROUP="dialout", ENV{silhouette_cameo}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="1123", GROUP="dialout", ENV{silhouette_portrait}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="1132", GROUP="dialout", ENV{silhouette_portrait2}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="113a", GROUP="dialout", ENV{silhouette_portrait3}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="111d", GROUP="dialout", ENV{silhouette_sd_2}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="111c", GROUP="dialout", ENV{silhouette_sd_1}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="110a", GROUP="dialout", ENV{craftrobo_cc200_20}="yes"
    ATTRS{idVendor}=="0b4d", ATTRS{idProduct}=="111a", GROUP="dialout", ENV{craftrobo_cc300_20}="yes"
  '';

  users.users.user.packages = with pkgs; [
    ours.install
    ((inkscape-with-extensions.override {
      inkscapeExtensions = with inkscape-extensions; [
        silhouette
        ours.toolbarExtension
        inkcut
      ];
    }).overrideAttrs (old: {
      # First file will win, i.e. Inkscape's file. Let's cheat a bit.
      buildCommand = old.buildCommand + ''
        ln -sfT ${ours.toolbarExtension}/share/inkscape/ui/toolbar-commands.ui $out/share/inkscape/ui/toolbar-commands.ui
      '';
    }))

    # Is Inkcut any good? Let's find out.
    inkcut
  ];
}
