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
      hash = "sha256-1d1jmr+9axSUxLdNv4OK2mzutROK3Wna2Z6Vkg9Mk98=";
    };

    #FIXME Patch doesn't work.
    #  Can we reproduce the issue outside of Inkscape?
    #  python3 -c 'import silhouette.read_dump; silhouette.read_dump.show_plotcuts([[[0,0],[10,10]]], buttons=True, extraText="abc")'
    #  -> Nope.
    # MPLBACKEND=gtk3agg python3 -c 'import matplotlib'
    # -> Libs are missing.
    # Use Python and GI_TYPELIB_PATH from Inkscape (read from /proc, GI_TYPELIB_PATH and NIX_PYTHONPREFIX):
    # GI_TYPELIB_PATH=... /nix/store/2m1m42zgmxh7n49dykhi01736ksg9a6q-python3-3.12.8-env/bin/python3 -c 'import silhouette.read_dump; silhouette.read_dump.show_plotcuts([[[0,0],[10,10]]], buttons=True, extraText="abc"); import matplotlib; print(matplotlib.get_backend())'
    # -> Backend is "gtk3agg" but no warnings.
    patches = [ ./01-disable-deprecation-warnings.patch ];

    # prerequisites = ["cssselect", "xmltodict", "lxml", "pyusb", "libusb1", "numpy"]
    propagatedBuildInputs = with pkgs.python3Packages; [
      libusb1
      inkex
    ];
  };

  extensions = pkgs.runCommand "inkscape-extensions-silhouette" {
    src = inkscape-silhouette.src;
    pypkgs = pkgs.python3.withPackages (p: with p; [
      inkscape-silhouette
      pyusb
      wxpython
      matplotlib
      xmltodict
    ]);
    sitepkgs = pkgs.python3.sitePackages;
  } ''
    mkdir $out
    for x in $pypkgs ; do
      cp -sr $x/$sitepkgs/* $out/
    done

    cp $src/{render_silhouette_regmarks,sendto_silhouette,silhouette_multi}.{py,inx} .
    chmod u+w *
    patch -p1 <${./01-disable-deprecation-warnings.patch}
    cp *.py *.inx $out/
  '';

  install = pkgs.writeShellScriptBin "install-inkscape-silhouette" ''
    set -e
    # This does not copy the file into the Nix store, so it will still be able to access
    # the files next to it (but it will be in the Nix store anyway when run from a Flake).
    nixfile=${builtins.toString ./.}/inkscape-silhouette-pkg.nix
    target=~/.config/inkscape
    target1=~/.config/inkscape/extensions
    target2=~/.config/inkscape/ui/toolbar-commands.ui
    if [ -e "$target1" -a ! -L "$target1" ] ; then
      ( set -x; mv --backup "$target1" "$target1.bak" )
    fi
    if [ -e "$target2" -a ! -L "$target2" ] ; then
      ( set -x; mv --backup "$target2" "$target2.bak" )
    fi
    [ ! -e "$target1" -o -L "$target1" ] && nix-build $nixfile -A extensions -o "$target1"
    [ ! -e "$target1" -o -L "$target1" ] && nix-build $nixfile -A toolbarFile -o "$target2"
  '';
in
{
  inherit toolbarFile inkscape-silhouette extensions install;
}
