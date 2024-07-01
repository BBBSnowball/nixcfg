{ config, pkgs, lib, routeromen, privateForHost, nixos-hardware, lanzaboote, ... }@args:
let
  #tinc-a-address = "192.168.83.139";
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      snowball-desktop
      network-manager
      desktop-base
      desktop.default
      hidpi
      #tinc-client-a
      vscode
      ssh-github
      flir
      allowUnfree
    ] ++
    [ ./hardware-configuration.nix
      ./users.nix
      #FIXME replace by 16'' variant when that is added
      nixos-hardware.nixosModules.framework-13-7040-amd
      ./secureBoot.nix
      lanzaboote.nixosModules.lanzaboote
      ./llm.nix
      ./mitmproxy.nix
      ./nix-serve.nix
    ];

  networking.hostName = "fwa";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.allowUnfreeByName = [
    "memtest86-efi"
  ];

  # Avoid seed being stored in word accessible location. These are the bootctl warnings for this:
  #   Mount point '/boot' which backs the random seed file is world accessible, which is a security hole!
  #   Random seed file '/boot/loader/random-seed' is world accessible, which is a security hole!
  # see https://forum.endeavouros.com/t/bootctl-install-outputs-some-warnings-about-efi-mount-point-and-random-seed-file-in-the-terminal/43991/6
  fileSystems."/boot".options = [
    #FIXME This is ignored here (but works for bettina-home). Why?!
    "fmask=0137,dmask=0027"
  ];

  networking.useNetworkd = true;

  networking.useDHCP = false;

  # WIFI is "unmanaged" (NetworkManager) and all other won't necessarily be online.
  boot.initrd.systemd.network.wait-online.timeout = 1;
  boot.initrd.systemd.network.wait-online.enable = false;
  systemd.services.systemd-networkd-wait-online.serviceConfig.ExecStart = lib.mkForce [ "" "${pkgs.coreutils}/bin/true" ];

#  networking.interfaces."tinc.a".ipv4.addresses = [ {
#    address = tinc-a-address;
#    prefixLength = 24;
#  } ];
#
#  systemd.network.wait-online.ignoredInterfaces = [ "tinc.a" ];

  nix.registry.routeromen.flake = routeromen;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    #"riscv32-linux"  # would build qemu. yuck.
    #"riscv64-linux"
    "wasm32-wasi"
    "wasm64-wasi"
  ];

  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark;  # wireshark-qt instead of wireshark-cli

  systemd.user.services.yubikey-touch-detector = {
    enable = true;
    description = "Detects when your YubiKey is waiting for a touch";
    path = with pkgs; [ yubikey-touch-detector ];
    script = ''exec yubikey-touch-detector'';
    environment.YUBIKEY_TOUCH_DETECTOR_LIBNOTIFY = "true";
  };

  programs.git.enable = true;
  programs.git.config = {
    user = { inherit (privateForHost.git) name email; };

    #https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work
    alias.logs = "log --pretty=\\\"format:%h %G? %<(8)%GS %<(15)%aN  %s\\\"";
  };

  environment.systemPackages = with pkgs; [
    mumble
    #wireshark
    zeal
    #lazygit
    #zgrviewer graphviz
    yubikey-manager yubikey-manager-qt yubikey-personalization
    freecad kicad graphviz blender
    libxslt zip  # used by Kicad
    wine
    #android-tools
    #virt-manager
    tigervnc
    #dfu-util
    rustup gcc
    #gqrx  # gnuradio
    #graph-easy  # dot graph to ascii graphic, e.g.: graph-easy /etc/tinc/$name/status/graph.dot
    #rpi-imager
    powerstat

    man-pages
    man-pages-posix
  ];

  documentation.dev.enable = true;

  # enabled by nixos-hardware but causes multi-second delays for login manager and swaylock
  services.fprintd.enable = false;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  programs.emacs.defaultEditor = lib.mkForce false;
  programs.vim.defaultEditor = true;

  #FIXME NixOS installer has added this to the default config. Do we want this? Move to our general config?
  security.rtkit.enable = true;

  services.fwupd.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  fonts.packages = with pkgs; [
    fira-code-nerdfont
    #terminus-nerdfont
    #inconsolata-nerdfont
    #fira-code
    #fira-code-symbols
  ];

  # `programs.command-not-found.enable` needs a Nix channel, so let's try this alternative
  # https://discourse.nixos.org/t/command-not-found-unable-to-open-database/3807/8
  programs.nix-index.enable = true;
  programs.command-not-found.enable = lib.mkForce false;

  services.blueman.enable = true;

  programs.kdeconnect.enable = true;
  #services.avahi.enable = true;

  environment.etc."systemd/dnssd/kdeconnect.dnssd".text = ''
    [Service]
    Name=%H
    Type=_kdeconnect._udp
    Port=1716
  '';

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry.gtk2;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
