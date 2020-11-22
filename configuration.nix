# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./gpd-pocket.nix
      ./wwan.nix
    ];

  # Use the systemd-boot EFI boot loader.
  #boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  #boot.loader.grub.useOSProber = true;

  boot.loader.grub.extraEntries = ''
    menuentry "Ubuntu" {
      search --set=ubuntu --fs-uuid 15ec06db-15c0-4ea5-8ee2-5ef17a60c767
      configfile "($ubuntu)/boot/grub/grub.cfg"
    }
  '';

  #boot.loader.grub.gfxmodeEfi = "1200x1920x32";
  boot.loader.grub.gfxmodeEfi = "1920x1200x32";

  networking.hostName = "snowball-gpd"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.wlp1s0.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  hardware.video.hidpi.enable = true;
  

  # Configure keymap in X11
  services.xserver.layout = "us";
  services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keyFiles = [ ./sshkeys.txt ];
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./sshkeys.txt ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget vim git tig byobu tmux htop usbutils
    firefox
    lm_sensors stress-ng
    i7z config.boot.kernelPackages.cpupower config.boot.kernelPackages.turbostat
    iw wirelesstools
    pavucontrol
    i2c-tools
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  networking.networkmanager.enable = true;
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome3.enable = true;
  services.tlp.enable = true;

  systemd.services.NetworkManager.preStart = ''
    mkdir -p /etc/NetworkManager/system-connections/
    install -m 700 -t /etc/NetworkManager/system-connections/ /etc/nixos/secret/nm-system-connections/*
  '';

  environment.interactiveShellInit = ''
    shopt -s histappend
    export HISTSIZE=300000
    export HISTFILESIZE=200000
  '';

  programs.vim.defaultEditor = true;

  hardware.enableRedistributableFirmware = true;

  boot.extraModulePackages = [
    (config.boot.kernelPackages.callPackage ./rtl8188gu.nix {})
  ];
  #boot.kernelModules = [ "8188eu" ];

  # "you are not privileged to build input-addressed derivations"
  # https://github.com/NixOS/nix/issues/2789
  # Remote user would have to be trusted by the remote machine and we certainly
  # don't want that for a build-only user!
  #nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "omen-verl-remote";
      system = "x86_64-linux";
      maxJobs = 4;
    }
  ];
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?

}

