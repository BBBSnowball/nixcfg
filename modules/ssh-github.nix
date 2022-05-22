{
  programs.ssh.extraConfig = ''
    # hack to allow multiple SSH keys for github
    # (because each key can only be used for one account or - more importantly - as a deploy key for a single repository)
    # Usage:
    # - create key github-myrepo: ssh-keygen -t rsa -b 4096 -f ~/.ssh/github-myrepo
    # - use this URL: github-myrepo:owner/myrepo
    Host github-*
        HostName github.com
        User git
        IdentitiesOnly yes
        IdentityFile ~/.ssh/%n
  '';
}
