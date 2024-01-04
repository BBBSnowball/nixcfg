{ lib, pkgs, ... }:
{
  services.networkd-dispatcher = {
    enable = true;
    rules.print-ip = {
      onState = [ "routable" "off" ];
      script = ''
        #!${pkgs.runtimeShell}
        PATH=${lib.makeBinPath (with pkgs; [ iproute2 jq inxi util-linux ])}:$PATH
        logger "print-ip: DEBUG: $IFACE, $AdministrativeState, $ADDR"
        if [[ $IFACE != "lo" && $AdministrativeState == "configured" ]]; then
          msg="$(
            echo "(print-ip via networkd-dispatcher)"
            echo ""
            ${pkgs.iproute2}/bin/ip -j a s | \
            ${pkgs.jq}/bin/jq -r '.[] | select(.ifname != "lo") |  select(.flags.[] | . == "UP") | .addr_info.[] | select(.family != "inet6" or (.temporary | not)) | (.local + " / " + (.prefixlen | tostring))'
            echo ""
            echo ""
            echo "IP: $ADDR on $IFACE"
            echo ""
          )"
          logger "print-ip: IP: $ADDR on $IFACE"
          logger "print-ip: $msg"
          for tty in /dev/tty{0,1,2,3} ; do
            echo "$msg" >$tty
          done
        fi
        exit 0
      '';
    };
  };

  systemd.services.print-ip-monitor = {
    wantedBy = [ "network-pre.target" ];
    path = with pkgs; [ iproute2 inxi util-linux ];
    script = ''
      HOME=/root inxi -v3 --tty -c2 --ip >/dev/tty0
      ip monitor address >/dev/tty0
    '';
  };

  systemd.services.print-ip = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ iproute2 jq inxi util-linux ];
    script = ''
      msg="$(
        echo "(print-ip service)"
        HOME=/root inxi --tty -c2 --ip
        ip -j a s | \
        jq -r '.[] | select(.ifname != "lo") |  select(.flags.[] | . == "UP") | .addr_info.[] | select(.family != "inet6" or (.temporary | not)) | (.local + " / " + (.prefixlen | tostring))'
        echo ""
      )"
      logger "print-ip: $msg"
      for tty in /dev/tty{0,1,2,3} ; do
        echo "$msg" >$tty
      done
    '';
  };
}
