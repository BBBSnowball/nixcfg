# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
let
  hostSpecificValue = path: import (./private/by-host/. + ("/" + config.networking.hostName) + path);
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./wifi-ap-eap/default.nix
      ./zsh.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # The bios sucks. It hangs in the POST screen after reboot. This might help:
  # https://serverfault.com/questions/126571/system-hangs-while-rebooting-on-debian/392886#392886
  boot.kernelParams = [ "reboot=hard,pci" ];

  networking.hostName = "routeromen";
  networking.hostId = hostSpecificValue /hostId.nix;
  networking.wireless.enable = false;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  #networking.interfaces.enp4s0.useDHCP = true;

  #networking.interfaces.br0.useDHCP = true;
  #networking.dhcpcd.persistent = true;
  networking.interfaces.br0.macAddress = "c8:d3:ff:44:05:14";
  networking.bridges.br0.interfaces = ["enp4s0" "enp2s0f0" "enp2s0f1" "enp2s0f2" "enp2s0f3" "wlp0s20f0u4"];
  # The FritzBox is often sending NAK so DHCP doesn't work most of the time.
  networking.interfaces.br0.ipv4 = {
    addresses = [ { address = "192.168.178.59"; prefixLength = 24; } ];
    routes = [ {
      address = "0.0.0.0";
      prefixLength = 0;
      via = "192.168.178.1";
    } ];
  };
  networking.nameservers = [ "192.168.178.1" ];

  services.hostapd = {
    enable = true;
    interface = "wlp0s20f0u4";
    ssid = "FRITZ!Box 7595";
  };
  services.wifi-ap-eap = {
    enable = true;
    countryCode = "DE";
    serverName = "ap.verl.bbbsnowball.de";
    #wifiFourAddressMode = true;
    serverCertValidDays = 3650;
    clientCertValidDays = 3650;
  };


  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  #i18n = {
  #  consoleFont = "Lat2-Terminus16";
  #  consoleKeyMap = "us";
  #  defaultLocale = "en_US.UTF-8";
  #};
  console.font = "Lat2-Terminus16";
  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget byobu tmux git tig cifs-utils pv file killall
    #vim
    htop iotop iftop cpufrequtils inteltool powertop stress stress-ng sysprof nethogs nix-top unixtools.top usbtop
    #FIXME throttled undervolt
    # atop ctop dnstop gotop nettop latencytop netatop gtop powerstat rPackages.gtop vtop
    # numatop nvtop pg_top radeontop
    pciutils usbutils lm_sensors
    smartmontools
    multipath-tools  # kpartx
    hdparm
    iperf iperf3
    utillinux parted

    qemu_kvm
    wirelesstools iw

    neovim neovim-remote fzf ctags
    # only in nixos unstable: page

    emacs-nox
  ];
  nixpkgs.overlays = [
    (self: super: {
      neovim = import ./submodules/jens-dotfiles/pkgs/neovim { pkgs = super; };
    })
    (self: super: {
      neovim = super.neovim.override (old: {
        viAlias = true;
        vimAlias = true;
        configure = old.configure // {
          packages = old.configure.packages // {
            myVimPackage2 = with pkgs.vimPlugins; {
              start = [
                #vim-buffergator
                #(pkgs.vimUtils.buildVimPlugin {
                #  name = "sidepanel.vim";
                #  src = pkgs.fetchFromGitHub {
                #    owner = "miyakogi";
                #    repo = "sidepanel.vim";
                #    rev = "0f8ff34a93cb15633fc0f79ae4ad8892ee772bf4";
                #    sha256 = "0qhhi6mq1llkvpq8j89kvdlfgzrk3vgmhja29r0636g08x6cynkr";
                #  };
                #})
                bufexplorer
                vim-orgmode
                #taglist
                tagbar
              ];
              opt = [
              ];
            };
          };
          customRC = old.configure.customRC + ''
            " set backspace=indent,eol,start

            "FIXME doesn't work
            "nnoremap <SPACE> <Nop>
            "let mapleader = "<SPACE>"

            noremap <SPACE>b <Cmd>Buffers<CR>
            noremap <SPACE>c <Cmd>Commands<CR>
            noremap <SPACE>f <Cmd>Files<CR>

            noremap <c-p> <Cmd>Files<CR>
            "noremap <c-s-p> <Cmd>Commands<CR>
            noremap <c-tab> <Cmd>bn<CR>
            tnoremap fd <C-\><C-n>

            tnoremap <A-h> <C-\><C-N><C-w>h
            tnoremap <A-j> <C-\><C-N><C-w>j
            tnoremap <A-k> <C-\><C-N><C-w>k
            tnoremap <A-l> <C-\><C-N><C-w>l
            inoremap <A-h> <C-\><C-N><C-w>h
            inoremap <A-j> <C-\><C-N><C-w>j
            inoremap <A-k> <C-\><C-N><C-w>k
            inoremap <A-l> <C-\><C-N><C-w>l
            nnoremap <A-h> <C-w>h
            nnoremap <A-j> <C-w>j
            nnoremap <A-k> <C-w>k
            nnoremap <A-l> <C-w>l

            "  " Set position (left or right) if neccesary (default: "left").
            "  let g:sidepanel_pos = "left"
            "  " Set width if neccesary (default: 32)
            "  let g:sidepanel_width = 26
            "  
            "  " To use rabbit-ui.vim
            "  "let g:sidepanel_use_rabbit_ui = 1
            "  
            "  " Activate plugins in SidePanel
            "  let g:sidepanel_config = {}
            "  let g:sidepanel_config['nerdtree'] = {}
            "  "let g:sidepanel_config['tagbar'] = {}
            "  "let g:sidepanel_config['gundo'] = {}
            "  let g:sidepanel_config['buffergator'] = {}
            "  "let g:sidepanel_config['vimfiler'] = {}
            "  "let g:sidepanel_config['defx'] = {}

            let g:org_todo_keywords = [['TODO(t)', 'CURRENT(c)', 'DEFER(l)', '|', 'DONE(d)', 'WONTFIX(w)']]
          '';
        };
      });
    })
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  # services.xserver.libinput.enable = true;

  # Enable the KDE Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.mutableUsers = false;
  users.users.benny = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPassword = hostSpecificValue /hashedPassword.nix;
    openssh.authorizedKeys.keyFiles = [ ./private/ssh-laptop.pub ];
  };
  users.users.root = {
    hashedPassword = hostSpecificValue /hashedPassword.nix;
    openssh.authorizedKeys.keyFiles = [ ./private/ssh-laptop.pub ];
  };
  users.users.test = {
    isNormalUser = true;
    hashedPassword = hostSpecificValue /hashedPassword.nix;
    openssh.authorizedKeys.keyFiles = [ ./private/ssh-laptop.pub ];
    packages = with pkgs; [
      anbox apktool
      android-studio # unfree :-(
      #androidenv.androidPkgs_9_0.platform-tools  # contains adb
      androidenv.androidPkgs_9_0.androidsdk
      adoptopenjdk-bin  # contains keytool and jarsigner
    ];
  };
  nixpkgs.config.android_sdk.accept_license = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "android-studio"
    "android-studio-stable"
  ];

  #programs.vim.defaultEditor = true;
  #environment.variables = { EDITOR = "vim"; };
  environment.etc."vimrc".text = ''
    inoremap fd <Esc>
  '';

  programs.bash.interactiveShellInit = ''
    shopt -s histappend

    if false ; then
    # https://www.reddit.com/r/neovim/comments/6npyjk/neovim_terminal_management_avoiding_nested_neovim/
    if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
      export VISUAL="nvr -cc tabedit --remote-wait +'set bufhidden=wipe'"
    else
      export VISUAL="nvim"
    fi
    EDITOR="$VISUAL"
    fi

    alias e="emacsclient --create-frame --tty --alternate-editor=\"\""
    export EDITOR="emacsclient -t"
  '';

  services.emacs.enable = true;
  services.emacs.package = pkgs.emacs-nox;


  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.09"; # Did you read the comment?

}

