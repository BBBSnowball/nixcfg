{ pkgs, config, secretForHost, ... }:
let
  node-media-server = import ./node-media-server { inherit pkgs; };
  injectpassword = import ./injectpassword { inherit pkgs; };
in
{
  systemd.user.services.node-media-server = let
    userService = "user@${toString config.users.users.node-media-server.uid}.service";
  in {
    unitConfig.ConditionUser = "node-media-server";
    # https://unix.stackexchange.com/a/590958
    #bindsTo = [ userService ];
    #after = [ "network.target" userService ];
    # -> We still cannot use `systemctl --user`.
    # -> Run both services as user services.

    after = [ "network.target" ];
    #wantedBy = [ "multi-user.target" ];
    wantedBy = [ "default.target" ];
    path = with pkgs; [ node-media-server ];
    serviceConfig = {
      ExecStart = "${node-media-server}/bin/my-node-media-server";
      Restart = "always";
      RestartSec = 30;
      #DynamicUser = true;
      #User = "node-media-server";
    };
  };

  users.users.node-media-server = {
    isSystemUser = true;
    group = "node-media-server";
    #uid = 5859;  # must be known in advance
    linger = true;
  };
  users.groups.node-media-server = {};

  systemd.user.services.stream-printer1 = {
    unitConfig.ConditionUser = "node-media-server";
    after = [ "network.target" "node-media-server.service" ];
    #wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ ffmpeg iputils nmap ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 30;
      #EnvironmentFile = "${secretForHost}/bambu";  # defines IP and ACCESS_CODE
      EnvironmentFile = "/tmp/bambu";  # defines IP and ACCESS_CODE
      #DynamicUser = true;
      #User = "stream-printer1";
    };
    script = ''
      INPUT="rtsps://bblp:$ACCESS_CODE@$IP:322/streaming/live/1"
      while true ; do
        #while ! ping -nc1 $IP >/dev/null ; do sleep 10 ; done
        while ! nmap -n $IP -Pn -sT -p 322 --noninteractive -oG - | grep -q /open/ ; do sleep 10 ; done

        echo "Start streaming..."
        # This would leak $ACCESS_TOKEN in process list. FFmpeg supports loading option values from a file,
        # e.g. with `-/filter`, but that doesn't work for `-i`. We couldn't find any easy way, so....
        # FFmpeg will still leak the password into stderr/journal in some cases, e.g. for invalid args.
        # It will sanitize the logged URL for other errors (e.g. couldn't connect).
        PW="$INPUT" PWN=3 \
          timeout -v -k 1m 5m \
          env LD_PRELOAD="${injectpassword}/injectpassword.so" \
          ffmpeg -re -i "<hidden>" -c copy -f flv rtmp://localhost/live/test -hide_banner -loglevel warning \
          || true
        sleep 10
      done
    '';
  };

  networking.firewall.interfaces.br0.allowedTCPPorts = [ 8087 ];

  services.shorewall.rules.fhem-web = {
    proto = "tcp";
    destPort = [ 8087 ];
    source = "loc,tinc:192.168.84.50,192.168.84.39";
  };

}
