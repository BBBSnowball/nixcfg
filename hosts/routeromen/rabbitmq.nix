{ config, pkgs, ... }:
let
  rabbitmq_3_13 = pkgs.rabbitmq-server.overrideAttrs (old: with pkgs; rec {
    pname = "rabbitmq-server";
    version = "3.13.7";
    name = "${pname}-${version}";
    src = fetchurl {
      url = "https://github.com/rabbitmq/rabbitmq-server/releases/download/v${version}/${pname}-${version}.tar.xz";
      hash = "sha256-GDUyYudwhQSLrFXO21W3fwmH2tl2STF9gSuZsb3GZh0=";
    };
  });
in
{
  services.rabbitmq = {
    enable = true;
    plugins = [
      "rabbitmq_management"
      "rabbitmq_mqtt"
      "rabbitmq_web_stomp"
    ];
    #config = "[{rabbitmq_mqtt, [{subscription_ttl, 10000}]}].";
    configItems = {
      #"mqtt.subscription_ttl" = "10000";
      "mqtt.max_session_expiry_interval_seconds" = "10";
      #"log.default.level" = "warning";
      "log.connection.level" = "warning";
    };

    # We cannot go from 3.12 to 4.0 without enabling some feature flags with 3.13.
    # Enable with: rabbitmqctl enable_feature_flag all
    #package = rabbitmq_3_13;
  };
}
