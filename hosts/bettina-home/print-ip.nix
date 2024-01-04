{ lib, pkgs, ... }:
{
  services.networkd-dispatcher = {
    enable = true;
    rules.print-ip = {
      onState = [ "routable" "off" ];
      script = ''
        #!${pkgs.runtimeShell}
        PATH=${lib.makeBinPath (with pkgs; [ iproute2 jq util-linux systemd ])}:$PATH
        logger "print-ip: DEBUG: $IFACE, $AdministrativeState, $OperationalState, $STATE, $ADDR, $IP_ADDRS"
        if [[ $IFACE != "lo" && $AdministrativeState == "configured" ]]; then
        #if [[ $IFACE != "lo" ]]; then
          msg="$(
            echo "(print-ip via networkd-dispatcher)"
            echo ""
            ${pkgs.iproute2}/bin/ip -j a s | \
            ${pkgs.jq}/bin/jq -r '.[] | select(.ifname != "lo") |  select(.flags.[] | . == "UP") | .addr_info.[] | select(.family != "inet6" or (.temporary | not)) | (.local + " / " + (.prefixlen | tostring))'
            echo ""
            echo ""
            networkctl status -n0
            echo ""
            echo ""
            echo "IP: $ADDR on $IFACE ($AdministrativeState), $IP_ADDRS"
            echo ""
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
    after = [ "getty.target" ];
    wantedBy = [ "network-pre.target" ];
    path = with pkgs; [ iproute2 util-linux ];
    script = ''
      ip -4 monitor address >/dev/tty0
    '';
  };

  systemd.services.inxi = {
    after = [ "getty.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ iproute2 inxi util-linux ];
    serviceConfig.Type = "oneshot";
    script = ''
      sleep 10
      HOME=/root inxi -v3 --tty -c2 --ip -Z >/dev/tty0
    '';
  };

  systemd.services.print-ip = {
    after = [ "network.target" "getty.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ iproute2 jq inxi util-linux ];
    serviceConfig.Type = "oneshot";
    script = ''
      msg="$(
        echo "(print-ip service)"
        #HOME=/root inxi --tty -c2 --ip
        ip -j a s | \
        jq -r '.[] | select(.ifname != "lo") |  select(.flags.[] | . == "UP") | .addr_info.[] | select(.family != "inet6" or (.temporary | not)) | (.local + " / " + (.prefixlen | tostring))'
        echo ""
        echo ""
      )"
      logger "print-ip: $msg"
      sleep 5
      for tty in /dev/tty{0,1,2,3} ; do
        echo "$msg" >$tty
      done
    '';
  };
}
