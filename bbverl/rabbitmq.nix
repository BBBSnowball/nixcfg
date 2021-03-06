{ config, pkgs, ... }:
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
      "mqtt.subscription_ttl" = "10000";
      #"log.default.level" = "warning";
      "log.connection.level" = "warning";
    };
  };
}
