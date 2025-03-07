#NOTE Example player is hosted on our fhem server, for now. Do this:
# ln -s /etc/nixos/flake/hosts/routeromen/flvjs /var/fhem/data/www/bambu

{ lib, pkgs, config, secretForHost, ... }:
let
  node-media-server = import ./node-media-server { inherit pkgs; };
  injectpassword = import ./injectpassword { inherit pkgs; };
in
{
  systemd.services.node-media-server = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ node-media-server systemd ];
    serviceConfig = {
      ExecStart = "${node-media-server}/bin/my-node-media-server";
      Restart = "always";
      RestartSec = 30;
      #DynamicUser = true;  # This would enable NoNewPrivileges but we want to use sudo.
      User = "node-media-server";
    };
  };

  users.users.node-media-server = {            
    isSystemUser = true;                       
    group = "node-media-server";               
  };                                           
  users.groups.node-media-server = {};         

  security.sudo.extraConfig = let
    systemctl = lib.getExe' pkgs.systemd "systemctl";
  in ''
    node-media-server ALL=NOPASSWD: ${systemctl} start stream-printer1.service, \
      ${systemctl} stop stream-printer1.service, \
      ${systemctl} restart stream-printer1.service
    #${systemctl} status stream-printer1.service  # -> not needed and might leak the access code in case of unusual errors
  '';

  systemd.services.stream-printer1 = {
    after = [ "network.target" "node-media-server.service" ];
    bindsTo = [ "node-media-server.service" ];  # stop us if node-media-server terminates
    #wantedBy = [ "multi-user.target" ];  # don't autostart us
    path = with pkgs; [ ffmpeg iputils nmap ];
    serviceConfig = {
      RestartSec = 30;
      EnvironmentFile = "${secretForHost}/bambu";  # defines IP and ACCESS_CODE
      DynamicUser = true;
      User = "stream-printer1";
      # Kill it if it doesn't stop rather soon.
      TimeoutStopSec = 5;
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
