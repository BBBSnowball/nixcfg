{ stdenv, python3, fetchzip, fetchFromGitHub, which }:
stdenv.mkDerivation {
  pname = "flash-zbdonge-p-firmware";
  version = "20230129";
  srcs = [
    (fetchzip {
      url = "https://github.com/Koenkk/Z-Stack-firmware/raw/1c3f97ca9ed3fea3112ee9c37012ba1d7907a0ef/coordinator/Z-Stack_3.x.0/bin/CC1352P2_CC2652P_launchpad_coordinator_20221226.zip";
      hash = "sha256-rRHT61GrLkSfv4OaKM50rbSjUCaRJzRlipEOb/2CzXk=";
    })
    (fetchFromGitHub {
      owner = "JelmerT";
      repo  = "cc2538-bsl";
      rev   = "538ea0deb99530e28fdf1b454e9c9d79d85a3970";  # 2022-08-03
      hash  = "sha256-fPY12kValxbJORi9xNyxzwkGpD9F9u3M1+aa9IlSiaE=";
    })
  ];
  firmwareFilename = "CC1352P2_CC2652P_launchpad_coordinator_20221226.hex";
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
        --)
          shift
          flasher_args+=("$@")
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
      # We are looking for a CP210x (10c4:ea60) but the product name has been set to
      # something useful so we rather use that.
      ttys=()
      for f in `grep -F "Sonoff Zigbee 3.0 USB Dongle Plus" -l /sys/bus/usb/devices/*/product` ; do
        for x in "`dirname "$f"`"/*\:*/ttyUSB*/tty/ttyUSB* ; do
          ttys+=`basename "$x"`
        done
      done
      case ''${#ttys[@]} in
        0)
          echo "No ZBDongle-P stick found. You can pass the correct serial port as an argument to this script if it isn't auto-detected." >&2
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
      set -x
      exec $PYTHON $FLASHER -p "$tty" --bootloader-sonoff-usb "''${flasher_args[@]}" -evw "$FIRMWARE"
    fi
  '';
  installPhase = ''
    srcs=($srcs)
    mkdir $out $out/bin
    cat - $scriptPath >$out/bin/$pname <<EOF
    #!`which bash` -e
    PYTHON=`which python3`
    FIRMWARE=''${srcs[0]}/$firmwareFilename
    FLASHER=''${srcs[1]}/cc2538-bsl.py
    EOF
    bash -n $out/bin/$pname
    chmod +x $out/bin/$pname
  '';
}
