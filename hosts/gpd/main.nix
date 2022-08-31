{ config, pkgs, routeromen, private, ... }@args:

{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      snowball-desktop
      network-manager
      desktop-base
      #tinc-client-a
      ssh-github
    ] ++
    [ ./hardware-configuration.nix
      (import ./gpd-pocket.nix args)
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

  networking.useDHCP = false;

  hardware.video.hidpi.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keyFiles = [ ./sshkeys.txt "${private}/ssh-framework-root.pub" ];
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./sshkeys.txt "${private}/ssh-framework-root.pub" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    firefox
    iw wirelesstools
    pavucontrol
    i2c-tools
    mumble
    freecad
    picocom
    ghidra-bin
  ];

  services.xserver.displayManager.gdm.enable = true;
  #services.xserver.desktopManager.gnome3.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.tlp.enable = true;

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

  services.geoclue2 = {
    enable = true;
  };

  #FIXME disabled because it conflicts with tlp but would it be better?
  services.power-profiles-daemon.enable = false;

  services.udev.extraRules = ''
    # GD32V bootloader
    ATTRS{idVendor}=="28e9", ATTRS{idProduct}=="0189", GROUP="users", MODE="0660"
  '';


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

}

