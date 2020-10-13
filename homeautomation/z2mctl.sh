# https://www.zigbee2mqtt.io/information/mqtt_topics_and_message_structure.html
case "$1" in
  permit_join)
    case "$2" in
      0|false|no)
        mosquitto_pub -t zigbee2mqtt/bridge/config/permit_join -m "false"
        ;;
      1|true|yes)
        mosquitto_pub -t zigbee2mqtt/bridge/config/permit_join -m "true"
        ;;
      *)
        echo "unsupported value" >&2
        exit 1
        ;;
    esac
    ;;
  log_level)
    case "$2" in
      debug|info|warn|error)
        mosquitto_pub -t zigbee2mqtt/bridge/config/log_level -m "$2"
        ;;
      *)
        echo "unsupported value" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unsupported command" >&2
    exit 1
    ;;
esac
