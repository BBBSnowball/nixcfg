#{ ... }: {
#  imports = [
#    <nixpkgs/nixos/modules/installer/cd-dvd/sd-image-aarch64.nix>
#  ];
#  # put your own configuration here, for example ssh keys:
#  users.extraUsers.root.openssh.authorizedKeys.keys = [
#     "ssh-ed25519 AAAAC3NzaC1lZDI1.... username@tld"
#  ];
#}

{ config, pkgs, lib, ... }:
{
  #nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.crossSystem = lib.systems.examples.raspberryPi;

  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;
 
  boot.kernelPackages = pkgs.linuxPackages_rpi0;
 
  # !!! Needed for the virtual console to work on the RPi 3, as the default of 16M doesn't seem to be enough.
  # If X.org behaves weirdly (I only saw the cursor) then try increasing this to 256M.
  # On a Raspberry Pi 4 with 4 GB, you should either disable this parameter or increase to at least 64M if you want the USB ports to work.
  boot.kernelParams = [
    "cma=32M" "console=ttyS0,115200n8" "console=ttyAMA0,115200n8" "console=tty0"
    "dwc_otg.lpm_enable=0" "root=/dev/nfs" "nfsroot=10.42.0.1:/pi/root" "rw" "ip=10.42.0.14:10.42.0.1::255.255.255.0:pi:usb0:static" "elevator=deadline" "modules-load=dwc2,g_ether" "fsck.repair=yes" "rootwait" "g_ether.host_addr=5e:a1:4f:5d:cf:d2"
    "dwc_otg.speed=0"
  ];
    
  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  boot.consoleLogLevel = lib.mkDefault 7;

  boot.initrd.availableKernelModules = [
    # Allows early (earlier) modesetting for the Raspberry Pi
    "vc4" "bcm2835_dma" "i2c_bcm2835"

    "g_ether" "libcomposite" "u_ether" "udc-core" "usb_f_rndis" "usb_f_ecm" "g_serial" "dwc2"
  ];

  documentation.enable = false;
  security.pam.services.su.forwardXAuth = lib.mkForce false;

  nixpkgs.overlays = [ (self: super: if super.stdenv.buildPlatform == super.stdenv.hostPlatform && super.stdenv.buildPlatform == super.stdenv.targetPlatform then {
  } else if super.stdenv.buildPlatform == super.stdenv.hostPlatform then {
    python3 = pkgs.pkgsBuildBuild.python3;
    python3Packages = pkgs.pkgsBuildBuild.python3Packages;
  } else (let dummy = pkgs.writeText "dummy" ""; in {
    python3 = dummy // { pkgs.buildPythonApplication = _: dummy; sitePackages = "dummy"; pythonForBuild = dummy; };
    python3Packages = {};
    python37 = dummy // { pkgs.buildPythonApplication = _: dummy; sitePackages = "dummy"; pythonForBuild = dummy; };
    python38 = dummy;
    python37Packages = {};
    python38Packages = {};
    python3Minimal = dummy;
    libGL = builtins.trace "libGL" dummy;
    mesa = builtins.trace "mesa" dummy;
    wayland = dummy;
    strace = dummy;
    ruby = builtins.trace "ruby" dummy;
    xscreensaver = dummy;
    linuxPackages_rpi0 = (super.linuxPackages_rpi0 // { bcc = dummy; });
    libxml2 = super.libxml2.override { pythonSupport = false; icuSupport = false; };
    libxslt = super.libxslt.override { pythonSupport = false; };
    itstool = dummy;
    meson = dummy;
    btrfs-progs = dummy;
    #xorg = super.xorg // { libXrender = null; libXt = null; xorgproto = null; libSM = null; libX11 = null; };
    cairo = null;
    pango = null;
    libpng = null;
    #guile = null;
    asciidoctor = null;
    gobject-introspection = null;
    gdb = null;
    libselinux = super.libselinux.override { enablePython = false; };
    #libselinux = null;
    aws-sdk-cpp = null;
    nix = super.nix.override { withAWS = false; };
    dbus = super.dbus.override { x11Support = false; };
    gtk-doc = null;
    audit = super.audit // { override = null; };

    enablePython = false;
    x11Support = false;

    # used by extraUtils in stage-1.nix
    #lvm2 = dummy;
    #mdadm = dummy;
  })) ];
  nixpkgs.config.allowBroken = true;
}
