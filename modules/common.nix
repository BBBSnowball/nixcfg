{ config, pkgs, lib, modules, nixpkgs, ... }:
{
  imports =
    [
      modules.args
      modules.zsh
      (if nixpkgs.lib.versionAtLeast nixpkgs.lib.version "23.10" then {} else ./loginctl-linger.nix)
      ./fix-sudo.nix
      modules.enable-flakes
      modules.hotfixes
      modules.nvim
      modules.tig
    ];

  environment.systemPackages = with pkgs; [
    wget byobu tmux tig cifs-utils pv file killall lzop vimpager
    dnsutils
    htop iotop iftop unixtools.top
    btop  # suggested by ahorn. I like it.
    pciutils usbutils lm_sensors
    smartmontools
    multipath-tools  # kpartx
    hdparm
    iperf iperf3
    utillinux parted
    lsof
    stress-ng
    inxi
    progress

    neovim neovim-remote fzf ctags
    # only in nixos unstable: page

    socat
    # not with programs.mosh.enable because we want to do firewall ourselves
    mosh

    ripgrep lf
    mtr
  ] ++ (if system == "x86_64-linux" then [
    # only for x86, i.e. not useful and/or not available for aarch64
    cpufrequtils
    i7z config.boot.kernelPackages.cpupower config.boot.kernelPackages.turbostat powertop
  ] else [])
  ++ builtins.filter (p: p != null) [
    # not available on older nixpkgs
    (pkgs.gitui or null)
  ];

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

  programs.tig.enable = true;
  programs.tig.configText = ''
    bind status A !git commit --amend
    bind main   I !git rebase -i %(commit)
    bind status U !git push
    bind main   U !git push
    bind status D !git pull
    bind main   D !git pull
    #NOTE 'R' is reload
    #NOTE revert is bound to '!', anyway
    #bind status R !git checkout %(file)
    
    bind status P !git patch-absolute %(file)
    
    bind status I !git-ignore --absolute %(file)
    
    # http://blogs.atlassian.com/2013/05/git-tig/#comment-101340
    
    # commit with diff
    bind status + !git commit -v
    bind status = !git commit –amend -v
    
    # make a commit that fixes another commit (use autosquash to squash it)
    bind main = !git commit --fixup=%(commit)
    #NOTE 'R' is reload
    #bind main R !git rebase --autosquash -i %(commit)
    
    bind status B !git tig-submodule %(file)

    # There doesn't seem to be any option to show signatures in the main view but we can
    # add them to some other views (e.g. in commit details, press enter in main view).
    # see https://github.com/jonas/tig/issues/208#issuecomment-352813725
    set log-options = --show-signature
    set diff-options = --show-signature
  '';

  # enable git here rather than adding it to systemPackages, so we can overwrite it to gitFull
  # without causing conflicts between git and gitFull packages
  programs.git = {
    enable = true;
    lfs.enable = true;
    package = lib.mkDefault pkgs.git;
  };
}
