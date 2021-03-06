{ config, ldap-to-ssh, flake-registry, ... }:
{
  imports = [ ldap-to-ssh.nixosModule ];

  config.users.groups.from-ldap = {
    gid = 900;
  };

  # shared user; all keys have access to it
  config.users.users.bernd = {
    isNormalUser = true;
    # treated like the LDAP users
    group = "from-ldap";
  };

  config.services.ldap-to-ssh = {
    enable = true;
    passwordFile = "/etc/nixos/secret/ldap-to-ssh/pw";
    httpPasswordFile = "/etc/nixos/secret/ldap-to-ssh/http-pw";
    keyOptions = "-F force_group=900 -F shared_user=bernd";
    requiredUsers = [ "bernd" ];
    forbiddenUsers = [ "root" ] ++ builtins.filter (x: x != "bernd") (builtins.attrNames config.users.users);
    extraValidateScript = ''
      mv $STATE_DIRECTORY/.new/passwd $STATE_DIRECTORY/.new/passwd2
      while IFS=: read -r username password userid groupid comment homedir cmdshell ; do
        if [ -z "$username" ] || ! grep -qE '^[a-zA-Z0-9]+$' <<<"$username" ; then
          echo "invalid username: $username" >&2
          exit
        fi
        if [ "$userid" -lt 4096 -o "$userid" -ge 5120 ] ; then
          echo "invalid uid: $userid" >&2
          exit
        fi
        if [ "$groupid" != 900 ] ; then
          echo "invalid gid: $groupid" >&2
          exit
        fi
        if [ "$homedir" != "/home/$username" ] ; then
          echo "invalid homedir: $homedir" >&2
          exit
        fi
        if [[ " $FORBIDDEN_USERS " =~ " $username " ]] ; then
          echo "forbidden user: $username" >&2
          exit
        fi
        echo "$username:x:$userid:900:$username:/home/$username:$cmdshell" >>$STATE_DIRECTORY/.new/passwd
      done < $STATE_DIRECTORY/.new/passwd2
      rm $STATE_DIRECTORY/.new/passwd2
      chmod a+r $STATE_DIRECTORY/.new/passwd
    '';
  };

  #FIXME move upstream
  config.systemd.services.ldap-to-ssh.after = [ "network.target" ];

  config.security.pam.services.sshd.makeHomeDir = true;
  config.security.pam.makeHomeDir.skelDirectory = "/etc/skel";

  # this is what the documentation says (XDG_CONFIG_HOME is empty/unset)
  # see https://nixos.org/manual/nix/unstable/command-ref/conf-file.html
  config.environment.etc."skel/.config/nix.conf".source = "/etc/user-nonet/nix.conf";
  # this is what strace shows:
  config.environment.etc."skel/.config/nix/nix.conf".source = "/etc/user-nonet/nix.conf";
  config.environment.etc."user-nonet/nix.conf".text = ''
    # use cached global registry instead of trying to download from Github
    flake-registry = ${flake-registry}/flake-registry.json
  '';
 
  config.networking.firewall.extraCommands = ''
    iptables -F OUTPUT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -d 136.243.151.7,136.243.151.58,94.79.177.226 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 22 ! -d 192.168.0.0/16 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 443 ! -d 192.168.0.0/16 -j ACCEPT
    iptables -A OUTPUT -m owner --gid-owner 30000 -d 192.168.0.0/16 -j REJECT --reject-with icmp-admin-prohibited
    iptables -A OUTPUT -m owner --gid-owner 900 -j REJECT --reject-with icmp-admin-prohibited
    ip6tables -A OUTPUT -m owner --gid-owner 900 -j REJECT --reject-with adm-prohibited
  '';
}
