{ stdenv, python3, fetchzip, fetchFromGitHub, which }:
stdenv.mkDerivation {
  pname = "flash-cc2652-firmware";
  version = "20210708";
  srcs = [
    (fetchzip {
      url = "https://github.com/Koenkk/Z-Stack-firmware/raw/5862746778ad3837422dacd4ebc6706f27678778/coordinator/Z-Stack_3.x.0/bin/CC2652RB_coordinator_20210708.zip";
      sha256 = "sha256-R6ZHtb6KRntqSFlWUOqV66h73wci+zNTZ7d/HnGGQRM=";
    })
    (fetchFromGitHub {
      owner = "JelmerT";
      repo  = "cc2538-bsl";
      rev   = "d31ce07fd022047d4e143d64e6d238f6baf139b6";  # 2020-10-07
      sha256 = "01k2czi6vwdgkwpih7bd2kzymhw3085adb263nwcaj33rlxj6k4z";
    })
  ];
  buildInputs = [
    (python3.withPackages (p: with p; [ pyserial intelhex magic ]))
  ];
  nativeBuildInputs = [ which ];
  phases = [ "installPhase" ];
  passAsFile = [ "script" ];
  script = ''
    tty=
    yes=0
    dry_run=0
    flasher_args=()
    while [ $# -gt 0 ] ; do
      case "$1" in
        -y|--yes)
          yes=1
          flasher_args+="-f"
          ;;
        -v|--verbose)
          flasher_args+="-V"
          ;;
        -n|--dry-run)
          dry_run=1
          ;;
        -*)
          echo "Unsupported argument: $1" >&2
          exit 1
          ;;
        *)
          if [ -n "$tty" -o ! -e "$1" ] ; then
            echo "Usage: $0 [--yes] [/dev/ttyUSBn]" >&2
            exit 1
          fi
          ;;
      esac
      shift
    done

    if [ -z "$tty" ] ; then
      # We are looking for a CP2101 (10c4:ea60) but the product name has been set to
      # something useful so we rather use that.
      ttys=()
      for f in `grep -F "slae.sh cc2652rb stick" -l /sys/bus/usb/devices/*/product` ; do
        for x in "`dirname "$f"`"/*\:*/ttyUSB*/tty/ttyUSB* ; do
          ttys+=`basename "$x"`
        done
      done
      case ''${#ttys[@]} in
        0)
          echo "No slae cc2652rb stick found. You can pass the correct serial port as an argument to this script if it isn't auto-detected." >&2
          exit 1
          ;;
        1)
          tty=/dev/"''${ttys[0]}"
          echo "Found slae cc2652rb stick: $tty"
          ;;
        2)
          echo "More than one stick found. Please choose one: ''${ttys[@]}"
          exit 1
          ;;
      esac
    fi

    if [ "$dry_run" -gt 0 ] ; then
      echo "would run:" $PYTHON $FLASHER -p "$tty" "''${flasher_args[@]}" -evw "$FIRMWARE"
    else
      exec $PYTHON $FLASHER -p "$tty" "''${flasher_args[@]}" -evw "$FIRMWARE"
    fi
  '';
  installPhase = ''
    srcs=($srcs)
    mkdir $out $out/bin
    cat - $scriptPath >$out/bin/$pname <<EOF
    #!`which bash` -e
    PYTHON=`which python3`
    FIRMWARE=''${srcs[0]}/CC2652RB_coordinator_20210708.hex
    FLASHER=''${srcs[1]}/cc2538-bsl.py
    EOF
    bash -n $out/bin/$pname
    chmod +x $out/bin/$pname
  '';
}
