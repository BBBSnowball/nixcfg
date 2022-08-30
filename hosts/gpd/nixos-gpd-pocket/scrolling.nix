# Scrolling emulation using trackpoint
# https://github.com/joshskidmore/gpd-pocket-arch-packages/tree/master/gpd-pocket-scrolling
{ pkgs, ... }:
{
  services.xserver.extraConfig = ''
    Section "InputClass"
      Identifier      "GPD trackpoint"
      MatchProduct    "SINO WEALTH Gaming Keyboard"
      MatchIsPointer  "on"
      Driver          "libinput"
      Option          "MiddleEmulation" "1"
      Option          "ScrollButton"    "3"
      Option          "ScrollMethod"    "button"
    EndSection
  '';

  nixpkgs.overlays = [(self: super: {
    wl-scroll-emulation = self.stdenv.mkDerivation {
      name = "wl-scroll-emulation";
      version = "0.1";

      src = self.fetchFromGitHub {
        owner = "PeterCxy";
        repo  = "scroll-emulation";
        rev   = "e5f0332a860ddca8b1dd647403fc99d96247f804";
        sha256 = "13dwa6jij8d4maq7chvmkxazp8mrd5mfm0lcfb94r914da8a6dxf";
      };

      buildInputs = [ self.libinput ];

      buildPhase = ''
        gcc -shared -ldl -linput -fPIC hook.c -o wl-scroll-emulation.so
      '';

      installPhase = ''
        mkdir -p $out/lib
        cp wl-scroll-emulation.so $out/lib
      '';
    };

    #gnome = (super.gnome.overrideScope' (self2: super2: {
    gnome = let super2 = super.gnome; self2 = self.gnome; in super.gnome // rec {
      # Don't replace gnome-shell because that would cause a lot of rebuilds.
      gnome-shell-patched = super2.gnome-shell.overrideAttrs (_: {
        src = null;
        phases = "installPhase";
        installPhase = ''
          ln -s ${super2.gnome-shell.devdoc} $devdoc
          mkdir $out
          ${pkgs.xorg.lndir}/bin/lndir -silent ${super2.gnome-shell} $out
          rm $out/bin/gnome-shell
          #makeWrapper $out/bin/gnome-shell ${super2.gnome-shell}/bin/gnome-shell --prefix LD_PRELOAD : "${self.wl-scroll-emulation}/lib/wl-scroll-emulation.so"
          #  -> makeWrapper refuses to process it because it is a script
          echo '#!${self.bash}/bin/bash' >$out/bin/gnome-shell
          echo 'export LD_PRELOAD="$LD_PRELOAD ${self.wl-scroll-emulation}/lib/wl-scroll-emulation.so' >>$out/bin/gnome-shell
          #echo 'exec ${super2.gnome-shell}/bin/gnome-shell "$@"' >>$out/bin/gnome-shell
          echo 'bla' >>$out/bin/gnome-shell
        '';
      });

      #gnome-session = super2.gnome-session.overrideAttrs (_: {
      #  src = null;
      #  phases = "installPhase";
      #  installPhase = ''
      #    ln -s ${super2.gnome-session.out} $out
      #    cp -r ${super2.gnome-session.sessions} $sessions
      #    chmod -R u+w $sessions
      #    for x in $sessions/share/{wayland-sessions,xsessions}/* ; do
      #      substituteInPlace $x \
      #        --replace super2.gnome-shell self2.gnome-shell-patched \
      #    done
      #  '';
      #});
      #gnome-session = super2.gnome-session.override { gnome = self2 // { gnome-shell = self2.gnome-shell-patched; }; };
    } // { gnome-shell = self.gnome.gnome-shell-patched; };
  })];
}
