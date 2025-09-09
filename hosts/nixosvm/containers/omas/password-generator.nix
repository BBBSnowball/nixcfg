{ pkgs, domain, ... }:
let
  src = pkgs.fetchFromGitHub {
    owner = "BBBSnowball";
    repo = "correcthorsebatterystaple";
    rev = "b0e1d6780dc6dfe54c318c3dda6ce48cbed293e7";
    hash = "sha256-eEmWCAtJc4QySX+Hox4stjWUux/K+mN3QSokWdnTzbw=";
  };

  pkg = (import (src + "/default.nix") { inherit pkgs; }).german;
  root = (pkgs.runCommand pkg.name {} ''
    mkdir $out
    ln -s ${pkg} $out/pw
  '').outPath;

  hostName = domain;
  webConfig = {
    locations."/pw" = {
      inherit root;
      index = "index.html";
    };
    locations."~ ^/pw/.*[.](js|css)$" = {
      # overwrite Wordpress' location rule for these files
      priority = 500;
      inherit root;
      # they have version hashes so we can keep the "expires max"
      extraConfig = ''
        expires max;
      '';
    };
    #extraConfig = ''
    #  rewrite "= /pw" $http_x_forwarded_proto://$http_x_forwarded_host/pw/ redirect;
    #  ~* \.(js|css|png|jpg|jpeg|gif|ico)$
    #'';
    locations."= /pw".return = "307 $http_x_forwarded_proto://$http_x_forwarded_host/pw/";
  };
in
{
  environment.etc.current-pw-generator-website.source = pkg.outPath;

  services.nginx.virtualHosts.${hostName} = webConfig;
  services.nginx.virtualHosts."www.${hostName}" = webConfig;
}
