{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, privateForHost, nixos-hardware, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
  tinc-a-address = "192.168.83.139";
  moreSecure = config.environment.moreSecure;
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      snowball-desktop
      network-manager
      desktop-base
      tinc-client-a
      vscode
      ssh-github
      #xonsh
      flir
      allowUnfree
    ] ++
    [ ./hardware-configuration.nix
      ./pipewire.nix
      ./mcu-dev.nix
      ./users.nix
      ./bluetooth.nix
      nixos-hardware.nixosModules.framework
      ./virtmanager.nix
      ./bl808-netboot.nix
      ./test-zigbee.nix
      ./hidpi.nix
      ./moreSecure.nix
      ./teensy.nix
      ./wireguard-test.nix
    ];

  environment.moreSecure = false;

  networking.hostName = "fw";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.allowUnfreeByName = [
    "memtest86-efi"
    "mfc9142cdnlpr"
    "helvetica-neue-lt-std"
  ];

  networking.useNetworkd = true;

  networking.useDHCP = false;

  # WIFI is "unmanaged" (NetworkManager) and all other won't necessarily be online.
  boot.initrd.systemd.network.wait-online.timeout = 1;
  boot.initrd.systemd.network.wait-online.enable = false;
  systemd.services.systemd-networkd-wait-online.serviceConfig.ExecStart = lib.mkForce [ "" "${pkgs.coreutils}/bin/true" ];

  networking.interfaces."tinc.a".ipv4.addresses = [ {
    address = tinc-a-address;
    prefixLength = 24;
  } ];

  services.tinc.networks.a.extraConfig = let name = "a"; in ''
    ConnectTo=orangepi_remoteadmin
  '';

  systemd.network.wait-online.ignoredInterfaces = [ "tinc.a" ];

  nix.registry.routeromen.flake = routeromen;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # desktop stuff
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  #services.xserver.desktopManager.gnome.enable = true;

  programs.sway.enable = true;
  programs.sway.wrapperFeatures.gtk = true;
  programs.sway.extraPackages = with pkgs; [
    alacritty kitty foot dmenu kupfer
    i3status i3status-rust termite rofi light
    swaylock
    wdisplays
    brightnessctl  # uses logind so doesn't need root
    sway-contrib.grimshot
    #yubikey-agent
    #yubikey-touch-detector
    mako
    pulseaudio
    playerctl
    libnotify
    (pkgs.runCommand "notify-helpers" { inherit (pkgs) jq; } ''
      mkdir $out/bin -p
      cp ${./notify-brightness.sh} $out/bin/notify-brightness
      substituteAll ${./notify-volume.sh} $out/bin/notify-volume
      chmod +x $out/bin/*
      patchShebangs $out/bin/*
    '')
  ];
  environment.etc."sway/config".source = ./sway-config;
  environment.etc."alacritty.yml".source = ./alacritty.yml;
  #environment.etc."i3status.conf".source = ./i3status.conf;
  environment.etc."xdg/i3status/config".source = ./i3status.conf;
  hardware.opengl.enable = true;
  # create /etc/X11/xkb for `localectl list-x11-keymap-options`
  # https://github.com/NixOS/nixpkgs/issues/19629#issuecomment-368051434
  services.xserver.exportConfiguration = true;

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
  programs.git.config = let
    p = import "${privateForHost}/git";
  in {
    user.name = p.name;
    user.email = p.email;

    # see https://developers.yubico.com/SSH/Securing_git_with_SSH_and_FIDO2.html
    # ssh-keygen -t ed25519-sk   # "-O resident" didn't work for me although Yubikey 5 should support up to 25 discoverable keys
    gpg.format = "ssh";
    #user.signingKey = "/etc/git/id_ed25519_sk";
    user.signingKey = "~/.ssh/id_ed25519_sk";
    #commit.gpgSign = "true";  # set for individual repositories only
    gpg.ssh.allowedSignersFile = "/etc/git/allowed_signers";

    #https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work
    alias.logs = "log --pretty=\\\"format:%h %G? %<(8)%GS %<(15)%aN  %s\\\"";
  };
  environment.etc."git/allowed_signers".source = "${privateForHost}/git/allowed_signers";
  environment.etc."git/id_ed25519_sk.pub".source = "${privateForHost}/git/id_ed25519_sk.pub";
  #environment.etc."git/id_ed25519_sk".source = "${privateForHost}/git/id_ed25519_sk";  # -> totally save for sk keys but still not accepted

  environment.systemPackages = with pkgs; [
    mumble
    picocom
    #wireshark
    zeal
    lazygit
    clementine
    entr
    zgrviewer graphviz
    yubikey-manager yubikey-manager-qt yubikey-personalization
    cura freecad kicad graphviz blender
    libxslt zip  # used by Kicad
    unzip
    inkscape
    wine
    android-tools
    virt-manager
    tigervnc
    tcpdump
    meld
    dfu-util
    zgrviewer
    lshw
    rustup gcc
    gqrx  # gnuradio
    graph-easy  # dot graph to ascii graphic, e.g.: graph-easy /etc/tinc/$name/status/graph.dot
    rpi-imager
  ];

  services.printing.drivers = [
    (pkgs.callPackage ../../pkgs/mfc9142cdncupswrapper.nix { mfc9142cdnlpr = pkgs.callPackage ../../pkgs/mfc9142cdnlpr.nix {}; })
    pkgs.brlaser
  ];
  #services.printing.extraConf = "LogLevel debug2";

  services.fwupd.enable = true;
  environment.etc."fwupd/remotes.d/lvfs-testing.conf".enable = false;
  environment.etc."fwupd/remotes.d/lvfs-testing.conf2" = {
    source = pkgs.runCommand "lvfs-testing.conf" {} ''
      sed 's/Enabled=false/Enabled=true/' <${config.environment.etc."fwupd/remotes.d/lvfs-testing.conf".source} >$out
    '';
    target = "fwupd/remotes.d/lvfs-testing.conf";
  };
#  environment.etc."fwupd/uefi_capsule.conf".enable = false;
#  environment.etc."fwupd/uefi_capsule.conf2" = {
#    source = pkgs.runCommand "uefi_capsule.conf" {} ''
#      cat <${config.environment.etc."fwupd/uefi_capsule.conf".source} >$out
#      echo "" >>$out
#      echo '# description says that we should do this:' >>$out
#      echo '# https://fwupd.org/lvfs/devices/work.frame.Laptop.TGL.BIOS.firmware' >>$out
#      echo 'DisableCapsuleUpdateOnDisk=true' >>$out
#    '';
#    target = "fwupd/uefi_capsule.conf";
#  };
  services.fwupd.uefiCapsuleSettings = {
    # description says that we should do this:
    # https://fwupd.org/lvfs/devices/work.frame.Laptop.TGL.BIOS.firmware
    DisableCapsuleUpdateOnDisk = true;
  };

  # enabled by nixos-hardware but causes multi-second delays for login manager and swaylock
  services.fprintd.enable = false;

  #fonts.fonts = with pkgs; [
  fonts.packages = with pkgs; [
    # needed for KiBot with rsvg
    helvetica-neue-lt-std
    libre-franklin
  ];

  services.openssh.enable = lib.mkForce (!moreSecure);

  programs.emacs.defaultEditor = lib.mkForce false;
  programs.vim.defaultEditor = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
