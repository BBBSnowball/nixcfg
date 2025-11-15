{ config, pkgs, lib, routeromen, privateForHost, nixos-hardware, lanzaboote, ... }@args:
let
  #tinc-a-address = "192.168.83.153";
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
      plymouth-subraum
    ] ++
    [
      nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
      #FIXME secure boot
      #./secureBoot.nix
      #lanzaboote.nixosModules.lanzaboote
      ./amdgpu.nix
      ./hardware-configuration.nix
      ./llm.nix
      ./users.nix
    ];

  networking.hostName = "fwd";

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
    "fmask=0137"
    "dmask=0027"
  ];

  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.useDHCP = false;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  
  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  programs.emacs.defaultEditor = lib.mkForce false;
  programs.vim.enable = true;
  programs.vim.defaultEditor = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry.gtk2;
  };

  services.tailscale.enable = true;

  documentation.dev.enable = true;

  services.fwupd.enable = true;

  fonts.packages = with pkgs; [
    #fira-code-nerdfont
    nerd-fonts.fira-code
    #terminus-nerdfont
    #inconsolata-nerdfont
    #fira-code
    #fira-code-symbols
  ];

  # `programs.command-not-found.enable` needs a Nix channel, so let's try this alternative
  # https://discourse.nixos.org/t/command-not-found-unable-to-open-database/3807/8
  programs.nix-index.enable = true;
  programs.command-not-found.enable = lib.mkForce false;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}

