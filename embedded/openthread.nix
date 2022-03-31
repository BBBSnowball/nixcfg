{ pkgs ? import <nixpkgs> {} }:
let
  # version mismatch between pc-ble-driver-py and pc-ble-driver in NixOS 21.05
  pc-ble-driver-py = if pkgs.python3Packages.pc-ble-driver-py.version == "0.15.0" && pkgs.pc-ble-driver.version == "4.1.1"
  then pkgs.python3Packages.pc-ble-driver-py.overrideAttrs (x: {
    version = "0.14.2";
    src = pkgs.fetchFromGitHub {
      owner = "NordicSemiconductor";
      repo = "pc-ble-driver-py";
      rev = "v0.14.2";
      sha256 = "1zbi3v4jmgq1a3ml34dq48y1hinw2008vwqn30l09r5vqvdgnj8m";
    };
  })
  else pkgs.python3Packages.pc-ble-driver-py;
  nrfutil = pkgs.nrfutil.override { python3Packages = pkgs.python3Packages // { inherit pc-ble-driver-py; }; };

  # I have no clue why nrfutil doesn't seem to support this by itself.
  nrf_trigger_bootloader = pkgs.writeScriptBin "nrf-trigger-bootloader" ''
    #! ${pkgs.python3.withPackages (p: [p.pyusb])}/bin/python3
    import usb.core, errno
    dev = usb.core.find(idVendor=0x1915, idProduct=0xcafe) or usb.core.find(idVendor=0x1915, idProduct=0xc00a)
    try:
      dev.ctrl_transfer(0x21, 0)
    except usb.core.USBError as e:
      if e.errno == errno.EPIPE:
        # This can indicate an error but it is also a normal consequence of the device detaching due to our request.
        pass
      else:
        raise
  '';

  openthread = pkgs.stdenv.mkDerivation {
    pname = "openthread";
    version = "20211001-313209";

    src = pkgs.fetchFromGitHub {
      owner  = "openthread";
      repo   = "openthread";
      rev    = "31320993fbf477a75c384b16529ea129a1f6d0e5";
      sha256 = "sha256-rVJotsa7wVgtYYz746KcM+zglpg6/MWI2qhRKyoaxBo=";
    };

    nativeBuildInputs = with pkgs; [ automake autoconf cmake libtool m4 ninja shellcheck python3 ];

    postPatch = ''
      patchShebangs .

      # third_party/nlbuild-autotools/repo/scripts/mkversion insists on using absolute paths
      # and it isn't as smart as make or configure: export AWK=$(which gawk); export BASENAME=$(which basename); export PRINTF=$(which printf)
      substituteInPlace third_party/nlbuild-autotools/repo/scripts/mkversion \
        --replace "\''${USRBINDIR}/" "" \
        --replace "\''${BINDIR}/" ""
    '';

    #configurePhase = ''./script/bootstrap'';
    dontConfigure = true;
    buildPhase = ''script/cmake-build posix -DOT_DAEMON=ON'';
  };

  openthread-nrf528xx = pkgs.stdenv.mkDerivation {
    pname = "openthread-nrf528xx";
    version = "20211001-95b27f";

    src = pkgs.fetchFromGitHub {
      owner  = "openthread";
      repo   = "ot-nrf528xx";
      rev    = "95b27f9143df64481b87eaa7a5507304d8f80cd9";
      sha256 = "sha256-x9WlgXEyru+K89DsPKilUK3aF7dnO+3UTTwOMt+UTjw=";
    };
    openthreadSrc = openthread.src;

    nativeBuildInputs = with pkgs; [
      automake autoconf cmake gcc-arm-embedded libtool m4 ninja shellcheck
      (python3.withPackages (p: [ p.yapf p.mdv ]))
      clang_9  # for clang-format and clang-tidy
    ];

    patches = [ ./ot-nrf528xx--diag-pullup-pulldown.patch ];

    postPatch = ''
      patchShebangs .

      ln -s $openthreadSrc openthread
    '';
  };
in
{
  inherit openthread openthread-nrf528xx;

  shell = pkgs.mkShell {
    buildInputs = with pkgs; [
      automake autoconf cmake gcc-arm-embedded libtool m4 ninja shellcheck
      (pkgs.callPackage ./nrfjprog.nix {})
      nrfutil
      picocom
      gdb
      nrf_trigger_bootloader
    ];

    shellHook = ''
      patchSources() {
        patchShebangs .

        # third_party/nlbuild-autotools/repo/scripts/mkversion insists on using absolute paths
        # and it isn't as smart as make or configure: export AWK=$(which gawk); export BASENAME=$(which basename); export PRINTF=$(which printf)
        substituteInPlace third_party/nlbuild-autotools/repo/scripts/mkversion \
          --replace "\''${USRBINDIR}/" "" \
          --replace "\''${BINDIR}/" ""
      }
    '';

    # OpenThread turns on -Werror and fortify without -O causes a warning
    hardeningDisable = [ "fortify" ];
  };
}

# https://openthread.io/codelabs/openthread-hardware#3
# git clone --recursive https://github.com/openthread/ot-nrf528xx.git
# ./script/build nrf52840 USB_trans -DOT_BOOTLOADER=USB -DOT_DIAGNOSTIC=ON
# #nrfutil pkg generate --application ot-rcp.hex --hw-version 52 --sd-req $(seq -s, 128 256) --application-version 42 ot-rcp.zip
# #nrfutil -v -v -v -v -v dfu usb-serial -pkg ot-rcp.zip --port /dev/serial/by-id/usb-Nordic_Semiconductor_Open_DFU_Bootloader_D3A06C859886-if00
# #for x in `seq 0 8 255` ; do echo "=== $x ==="; nrfutil pkg generate --application ot-rcp.hex --hw-version 52 --sd-req $(seq -s, $x $[$x+7]) --application-version 42 ot-rcp.zip && nrfutil -v -v -v -v -v dfu usb-serial -pkg ot-rcp.zip --port /dev/serial/by-id/usb-Nordic_Semiconductor_Open_DFU_Bootloader_D3A06C859886-if00 && break ; done
# -> 0 seems to work
# #( cd build/bin && nrfutil pkg generate --application ot-rcp.hex --hw-version 52 --sd-req 0 --application-version 42 ot-rcp.zip && nrfutil -v dfu usb-serial -pkg ot-rcp.zip --port /dev/serial/by-id/usb-Nordic_Semiconductor_Open_DFU_Bootloader_D3A06C859886-if00 )
# NAME=ot-cli-ftd; ( cd build/bin && arm-none-eabi-objcopy -O ihex $NAME $NAME.hex && nrfutil pkg generate --application $NAME.hex --hw-version 52 --sd-req 0 --application-version 42 $NAME.zip && nrfutil -v dfu usb-serial -pkg $NAME.zip --port /dev/serial/by-id/usb-Nordic_Semiconductor_Open_DFU_Bootloader_*-if00 )
# #ip tuntap add mode tun user test dev openthread && ip link set dev openthread mtu 1280
# unshare -rUn
# cd ~/openthread/openthread; ./build/posix/src/posix/ot-daemon -v -v -d 127 'spinel+hdlc+uart:///dev/ttyACM1?uart-baudrate=115200' -I openthread2
# cd ~/openthread/openthread; build/posix/src/posix/ot-ctl -I openthread2

# ot-cli-ftd:
#   P0.06, diag gpio out 6, bright green, low active
#   P0.08, diag gpio out 8, blue, bootloader, low active
#   P1.09, diag gpio out 41, green, low active
#   P0.12, diag gpio out 12, red, low active
#   P1.06, diag gpio 38, low active, needs pullup (with my patch: diag gpio pu 38)
#   (all of them need `diag start`)
#   https://infocenter.nordicsemi.com/index.jsp?topic=%2Fug_nrf52840_dongle%2FUG%2Fnrf52840_Dongle%2Fhw_swd_if.html

# How to trigger the bootloader?
# https://infocenter.nordicsemi.com/index.jsp?topic=%2Fcom.nordic.infocenter.sdk5.v15.0.0%2Flib_dfu_trigger_usb.html
# https://www.usb.org/sites/default/files/DFU_1.1.pdf
# https://devzone.nordicsemi.com/f/nordic-q-a/58703/nrf52840-dongle-v1-2-0-schematic
# -> P0.19 is one of those connected to RESET.
# -> `diag gpio out 19` does indeed reset into the bootloader.
#
#    Interface Descriptor:
#      bInterfaceClass       255 Vendor Specific Class
#      ...
#      ** UNRECOGNIZED:  09 21 09 00 00 00 00 10 01
# 1915:c00a Nordic Semiconductor ASA nRF52 Connectivity
# 1915:521f Nordic Semiconductor ASA Open DFU Bootloader
# 1915:cafe Nordic Semiconductor ASA nRF528xx OpenThread Device

