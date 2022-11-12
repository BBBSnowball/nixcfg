{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, private, nixos-hardware, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
  hostSpecificValue = path: import "${private}/by-host/${config.networking.hostName}${path}";
  tinc-a-address = "192.168.83.139";
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
      xonsh
      flir
    ] ++
    [ ./hardware-configuration.nix
      ./pipewire.nix
      ./mcu-dev.nix
      (import ./users.nix { inherit pkgs private; })
      ./bluetooth.nix
      nixos-hardware.nixosModules.framework
    ];

  networking.hostName = "fw";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "memtest86-efi"
    "vscode"
    "mfc9142cdnlpr"
  ];

  networking.useDHCP = false;

  networking.interfaces."tinc.a".ipv4.addresses = [ {
    address = tinc-a-address;
    prefixLength = 24;
  } ];

  services.tinc.networks.a.extraConfig = let name = "a"; in ''
    # tincd chroots into /etc/tinc/${name} so we cannot put the file into /run, as we usually would.
    # Furthermore, tincd needs write access to the directory so we make a subdir.
    GraphDumpFile = status/graph.dot

    ConnectTo=orangepi_remoteadmin
  '';
  systemd.services."tinc.a" = let name = "a"; in {
    preStart = ''
      ${pkgs.coreutils}/bin/install -o tinc.${name} -m755 -d /etc/tinc/${name}/status
    '';
    serviceConfig.BindPaths = [
      #"/etc/tinc/a/graph.dot=/run/tinc-${name}/graph.dot"
    ];
  };
  # NixOS network config doesn't setup the interface if we restart the tinc daemon
  # so let's add some redundancy:
  environment.etc."tinc/a/tinc-up" = {
    text = ''
      #!/bin/sh
      ${pkgs.nettools}/bin/ifconfig $INTERFACE ${tinc-a-address} netmask 255.255.255.0
    '';
    mode = "755";
  };
  environment.etc."tinc/a/tinc-down" = {
    text = ''
      #!/bin/sh
      ${pkgs.nettools}/bin/ifconfig $INTERFACE down
    '';
    mode = "755";
  };

  nix.registry.routeromen.flake = routeromen;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # desktop stuff
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  programs.sway.enable = true;
  programs.sway.wrapperFeatures.gtk = true;
  programs.sway.extraPackages = with pkgs; [
    alacritty kitty foot dmenu kupfer
    i3status i3status-rust termite rofi light
    swaylock
    wdisplays
    brightnessctl  # uses logind so doesn't need root
    sway-contrib.grimshot
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

  environment.systemPackages = with pkgs; [
    mumble
    picocom
    #wireshark
    zeal
    lazygit
    clementine
    entr
    zgrviewer graphviz
  ];

  services.printing.drivers = [
    (pkgs.callPackage ../../pkgs/mfc9142cdncupswrapper.nix { mfc9142cdnlpr = pkgs.callPackage ../../pkgs/mfc9142cdnlpr.nix {}; })
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
  environment.etc."fwupd/uefi_capsule.conf".enable = false;
  environment.etc."fwupd/uefi_capsule.conf2" = {
    source = pkgs.runCommand "uefi_capsule.conf" {} ''
      cat <${config.environment.etc."fwupd/uefi_capsule.conf".source} >$out
      echo "" >>$out
      echo '# description says that we should do this:' >>$out
      echo '# https://fwupd.org/lvfs/devices/work.frame.Laptop.TGL.BIOS.firmware' >>$out
      echo 'DisableCapsuleUpdateOnDisk=true' >>$out
    '';
    target = "fwupd/uefi_capsule.conf";
  };

  # enabled by nixos-hardware but causes multi-second delays for login manager and swaylock
  services.fprintd.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}