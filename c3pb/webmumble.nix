{ config, pkgs, lib, ... }:
let
  extractTarball = tarball: builtins.derivation {
    name = builtins.baseNameOf tarball;
    builder = pkgs.writeShellScript "extract-tar" ''
      ${pkgs.coreutils}/bin/mkdir $out
      ${pkgs.gnutar}/bin/tar -C $out -xf $tarball
    '';
    inherit tarball;
    system = builtins.currentSystem;
  };
  webmumbleDist = extractTarball ./mumble-web-dist.tar;
  port = 8020;

  # our Mumble is using ancient crypto...
  opensslConf = pkgs.writeText "openssl.conf" ''
    [system_default_sect]
    MinProtocol = TLSv1.0
    CipherString = DEFAULT@SECLEVEL=2
  '';
in {
  networking.firewall.allowedTCPPorts = [ port ];

  systemd.services.webmumble = {
    description = "Service to forward websocket connections to TCP connections for webmumble";
    serviceConfig.ExecStart = ''
      ${pkgs.pythonPackages.websockify}/bin/websockify --ssl-target \
        --web=${webmumbleDist} \
        0.0.0.0:${toString port} ${lib.fileContents ../private/mumble-domain-c3pb.txt}:64738
    '';
    wantedBy = [ "multi-user.target" ];
    environment.OPENSSL_CONF = opensslConf;
    serviceConfig.DynamicUser = "yes";
  };
}
