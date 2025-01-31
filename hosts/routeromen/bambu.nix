{ pkgs, secretForHost, ... }:
let
  node-media-server = import ./node-media-server { inherit pkgs; };
in
{
  systemd.services.node-media-server = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ node-media-server ];
    serviceConfig = {
      ExecStart = "${node-media-server}/bin/my-node-media-server";
      Restart = "always";
      RestartSec = 30;
      DynamicUser = true;
      User = "node-media-server";
    };
  };

  systemd.services.stream-printer1 = {
    after = [ "network.target" "node-media-server.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ ffmpeg iputils nmap ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 30;
      EnvironmentFile = "${secretForHost}/bambu";  # defines IP and ACCESS_CODE
      DynamicUser = true;
      User = "stream-printer1";
    };
    script = ''
      while true ; do
        #while ! ping -nc1 $IP >/dev/null ; do sleep 10 ; done
        while ! nmap -n $IP -Pn -sT -p 322 --noninteractive -oG - | grep -q /open/ ; do sleep 10 ; done

        echo "Start streaming..."
        #FIXME This will leak $ACCESS_TOKEN in process list! And also in journal because ffmpeg will sometimes mention it in log messages.
        ffmpeg -re -i rtsps://bblp:$ACCESS_CODE@$IP:322/streaming/live/1 -c copy -f flv rtmp://localhost/live/test -hide_banner -loglevel warning
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
