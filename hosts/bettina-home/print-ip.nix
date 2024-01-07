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
          # use crlf line endings because terminal will be in raw mode if we successfully started an ncurses system monitor
          msg="''${msg//$'\n'/$'\r\n'}"
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
      ip -4 monitor address | sed 's/$/\r/' >/dev/tty1
    '';
  };

  systemd.services.inxi = {
    after = [ "getty.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ iproute2 inxi util-linux ];
    serviceConfig.Type = "oneshot";
    script = ''
      sleep 10
      HOME=/root inxi -v3 --tty -c2 --ip -Z | sed 's/$/\r/' >/dev/tty1
      HOME=/root inxi -v3 --tty -c2 --ip -Z >/dev/tty2
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
      # use crlf line endings because terminal will be in raw mode if we successfully started an ncurses system monitor
      msg="''${msg//$'\n'/$'\r\n'}"
      for tty in /dev/tty{0,1,2,3} ; do
        echo "$msg" >$tty
      done
    '';
  };

  systemd.services.glances = {
    after = [ "getty.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ glances ];
    environment.TERM = "linux";
    #NOTE We shouldn't provide /dev/null as stdin for glances because that would take 100% CPU.
    #     We could create a named pipe but now that we run it with dropped priviledges, we can just allow user input
    #     and this is more convenient for the user anyway.
    serviceConfig = {
      DynamicUser = true;
      StandardInput = "tty-force";
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
      ExecStart = "${pkgs.glances}/bin/glances -t 10";
    };
  };

  # disable getty on tty1 so it doesn't interfere with our output
  systemd.services."autovt@tty0".enable = false;
}
