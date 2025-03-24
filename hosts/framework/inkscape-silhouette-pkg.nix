# Usage: nix-build inkscape-silhouette.nix -A install && ./result/bin/install-inkscape-silhouette
{ pkgs ? import <nixpkgs> {} }:
let
  # add Toolbar buttons to Inkscape's UI
  # see https://www.reddit.com/r/Inkscape/comments/12061oi/comment/jdgc9iy/
  #FIXME only the button for remarks is usable. Why?
  toolbarFile = pkgs.runCommand "toolbar-commands.ui" {
    inherit (pkgs) inkscape gnused xmlstarlet;
    buttons = ''
      <child>
        <object class="GtkToolButton">
          <property name="action_name">app.com.github.fablabnbg.inkscape-silhouette.sendto_silhouette</property>
          <property name="icon_name">inkscape-logo</property>
        </object>
      </child>
      <child>
        <object class="GtkToolButton">
          <property name="action_name">app.com.github.fablabnbg.inskscape-silhouette.silhouette_multi</property>
          <property name="icon_name">inkscape-logo</property>
        </object>
      </child>
      <child>
        <object class="GtkToolButton">
          <property name="action_name">app.com.github.fablabnbg.inkscape-silhouette.silhouette-regmarks</property>
          <property name="icon_name">inkscape-logo</property>
        </object>
      </child>
    '';
    passAsFile = [ "buttons" ];
  } ''
    export PATH=$PATH:$gnused/bin:$xmlstarlet/bin
    in=$inkscape/share/inkscape/ui/toolbar-commands.ui
    xmlstarlet ed --insert "//object[@id='commands-toolbar']/style" --type elem -n insert_here $in >tmp.xml
    (
      sed <tmp.xml '/^\s*<insert_here *\/>$/,/$ / d'
      sed 's/^/    /' < $buttonsPath
      sed <tmp.xml '0,/^\s*<insert_here *\/>$/ d'
    ) >$out
    diff -u10 $in $out || true
    xmlstarlet val -w $out
  '';

  inkscape-silhouette = pkgs.python3Packages.buildPythonPackage {
    name = "inkscape-silhouette";

    src = pkgs.fetchFromGitHub {
      owner = "fablabnbg";
      repo = "inkscape-silhouette";
      rev = "1e8261eeac70e753b5df2415cc0e896fd67ae994";
    };

    # prerequisites = ["cssselect", "xmltodict", "lxml", "pyusb", "libusb1", "numpy"]
    propagatedBuildInputs = with pkgs.python3Packages; [
      libusb1
      inkex
    ];
  };

  extensions = pkgs.runCommand "inkscape-extensions-silhouette" {
    py = inkscape-silhouette;
    inherit (pkgs) libusb1;
    inherit (pkgs.python3Packages) pyusb;
    src = inkscape-silhouette.src;
  } ''
    mkdir $out
    ln -s $py/lib/python3.12/site-packages/silhouette $out/silhouette
    #ln -s $libusb1 $out/libusb1
    ln -s $pyusb/lib/python3.12/site-packages/usb $out/usb
    ln -s $src/render_silhouette_regmarks.inx $out/render_silhouette_regmarks.inx
    ln -s $src/sendto_silhouette.inx $out/sendto_silhouette.inx
    ln -s $src/silhouette_multi.inx $out/silhouette_multi.inx
    ln -s $src/render_silhouette_regmarks.py $out/render_silhouette_regmarks.py
    ln -s $src/sendto_silhouette.py $out/sendto_silhouette.py
    ln -s $src/silhouette_multi.py $out/silhouette_multi.py
  '';

  install = pkgs.writeShellScriptBin "install-inkscape-silhouette" ''
    set -e
    target=~/.config/inkscape
    target1=~/.config/inkscape/extensions
    target2=~/.config/inkscape/ui/toolbar-commands.ui
    if [ -e "$target1" -a ! -L "$target1" ] ; then
      ( set -x; mv --backup "$target1" "$target1.bak" )
    fi
    if [ -e "$target2" -a ! -L "$target2" ] ; then
      ( set -x; mv --backup "$target2" "$target2.bak" )
    fi
    [ ! -e "$target1" -o -L "$target1" ] && nix-build ./inkscape-silhouette.nix -A extensions -o "$target1"
    [ ! -e "$target1" -o -L "$target1" ] && nix-build ./inkscape-silhouette.nix -A toolbarFile -o "$target2"
  '';
in
{
  inherit toolbarFile inkscape-silhouette extensions install;
}
