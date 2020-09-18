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
      "rabbitmq_mqtt.subscription_ttl" = "10000";
    };
  };
}
