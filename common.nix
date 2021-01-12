{ pkgs, lib, modules, ... }:
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

    neovim neovim-remote fzf ctags
    # only in nixos unstable: page

    socat
    # not with programs.mosh.enable because we want to do firewall ourselves
    mosh
  ] ++ (if system == "x86_64-linux" then [
    cpufrequtils
  ] else []);

  #programs.vim.defaultEditor = true;
  #environment.variables = { EDITOR = "vim"; };
  environment.etc."vimrc".text = ''
    inoremap fd <Esc>
  '';

  programs.bash.interactiveShellInit = ''
    shopt -s histappend
  '';
}
