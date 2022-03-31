{ config, pkgs, lib, modules, ... }:
{
  imports =
    [
      modules.zsh
      ./loginctl-linger.nix
      ./fix-sudo.nix
      modules.enable-flakes
      modules.nvim
    ];

  environment.systemPackages = with pkgs; [
    wget byobu tmux git tig cifs-utils pv file killall lzop vimpager
    dnsutils
    htop iotop iftop unixtools.top
    pciutils usbutils lm_sensors
    smartmontools
    multipath-tools  # kpartx
    hdparm
    iperf iperf3
    utillinux parted
    lsof
    stress-ng

    neovim neovim-remote fzf ctags
    # only in nixos unstable: page

    socat
    # not with programs.mosh.enable because we want to do firewall ourselves
    mosh

    ripgrep lf
  ] ++ (if system == "x86_64-linux" then [
    cpufrequtils
    i7z config.boot.kernelPackages.cpupower config.boot.kernelPackages.turbostat powertop
  ] else []);

  #programs.vim.defaultEditor = true;
  #environment.variables = { EDITOR = "vim"; };
  environment.etc."vimrc".text = ''
    inoremap fd <Esc>
  '';

  programs.bash.interactiveShellInit = ''
    shopt -s histappend
    export HISTSIZE=300000
    export HISTFILESIZE=200000
  '';

  environment.etc."lf/lfrc".text = ''
    set incsearch
    #set globsearch  # breaks incsearch because matches the whole name
    set scrolloff 3
    map U !du -sh
    map T $tig
    set ifs "\n"
    set shellopts '-eu'
  '';
}
