# https://github.com/NixOS/nixpkgs/blob/88f00e7e12d2669583fffd3f33aae01101464386/pkgs/os-specific/linux/device-tree/default.nix
{ stdenvNoCC, dtc, findutils, lib }:

with stdenvNoCC.lib; {
  applyOverlays = (base: overlays: stdenvNoCC.mkDerivation {
    name = "device-tree-overlays";
    nativeBuildInputs = [ dtc findutils ];
    inherit base;
    #overlays = lib.strings.escapeShellArgs (toList overlays);
    overlays = toList overlays;
    buildCommand = ''
      dtbos=()
      for dt in $overlays; do
        if [ "$(od -N4 -A n -t x1 "$dt")" == " d0 0d fe ed" ] ; then
          dtbos+=("$dt")
        else
          echo "dtc: $dt"
          tmp="$(mktemp -p . "$(basename "$dt")-XXXXXXXX")"
          dtc -@ -I dts -O dtb -o "$tmp" "$dt"
          dtbos+=("$tmp")
        fi
      done
      nomatch=0
      for dtb in $(find $base -name "*.dtb" ); do
        dtbos2=()
        for overlay in "''${dtbos[@]}"; do
          comp1="$(fdtget -t s "$dtb" / compatible 2>/dev/null)"
          comp2="$(fdtget -t s "$overlay" / compatible 2>/dev/null)"
          if [ -z "$comp1" -o -z "$comp2" ] ; then
            dtbos2+=("$overlay")
          else
            found=0
            for a in $comp1; do
              for b in $comp2; do
                if [ "$a" == "$b" ]; then
                  found=1
                  break
                fi
              done
              if [ $found != 0 ] ; then
                break
              fi
            done
            if [ $found == 1 ] ; then
              dtbos2+=("$overlay")
            fi
          fi
        done

        outDtb=$out/$(realpath --relative-to "$base" "$dtb")
        mkdir -p "$(dirname "$outDtb")"
        if [ ''${#dtbos2[@]} -gt 0 ] ; then
          echo "for: $(realpath --relative-to "$base" "$dtb")"
          echo "  overlays: ''${dtbos2[@]}"
          fdtoverlay -o "$outDtb" -i "$dtb" "''${dtbos2[@]}";
        else
          #echo "cp:  $(realpath --relative-to "$base" "$dtb")"
          cp "$dtb" "$outDtb"
          nomatch=$[$nomatch+1]
        fi
      done
      if [ $nomatch -gt 0 ] ; then
        echo "$nomatch device trees are unchanged."
      fi
    '';
  });
}
