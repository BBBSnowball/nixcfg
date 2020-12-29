{ pkgs, lib, ... }@args:
let
  modules = args.modules or (import ./modules.nix {});
in {
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
