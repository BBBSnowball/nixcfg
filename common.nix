{ pkgs, modules ? import ./modules.nix { inherit pkgs; }, ... }:
{
  imports =
    [
      modules.zsh
      ./loginctl-linger.nix
      ./fix-sudo.nix
      ./enable-flakes.nix
      modules.nvim
    ];

  environment.systemPackages = with pkgs; [
    wget byobu tmux git tig cifs-utils pv file killall lzop
    dnsutils
    htop iotop iftop cpufrequtils unixtools.top
    pciutils usbutils lm_sensors
    smartmontools
    multipath-tools  # kpartx
    hdparm
    iperf iperf3
    utillinux parted
    lsof

    neovim neovim-remote fzf ctags
    # only in nixos unstable: page
  ];

  #programs.vim.defaultEditor = true;
  #environment.variables = { EDITOR = "vim"; };
  environment.etc."vimrc".text = ''
    inoremap fd <Esc>
  '';

  programs.bash.interactiveShellInit = ''
    shopt -s histappend
  '';
}
