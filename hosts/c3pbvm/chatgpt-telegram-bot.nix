{ pkgs, chatgpt-telegram-bot, secretForHost, ... }:
let
  name = "chatgpt-telegram-bot";
  pkg = chatgpt-telegram-bot.packages.${pkgs.system}.${name};
in
{
  systemd.services.${name} = {
    after = ["network.target"];
    description = "Telegram Bot for ChatGPT";
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 10;
      LoadCredential = "config.json:${secretForHost}/chatgpt-telegram-bot-config.json";
      RuntimeDirectory = name;
      WorkingDirectory = "/run/${name}";
      User = name;
      DynamicUser = true;
    };
    wantedBy = [ "multi-user.target" ];

    environment.APP = pkg;
    environment.LIB = pkg.lib;
    environment.NODEJS = pkg.passthru.nodejs;
    script = ''
      install -m 0700 -d work work/config
      cd work
      ln -s ''${CREDENTIALS_DIRECTORY}/config.json config/default.json

      # We have to add $LIB/node_modules to make `extensionless` available.
      # Well, it turns out that setting $NODE_PATH is not the same as having the directory in
      # the local hierarchy. Whatever... let's get this done already.
      NODE_PATH=$LIB/node_modules
      ln -sfT $LIB/node_modules node_modules

      exec $NODEJS/bin/node --experimental-loader=extensionless $(realpath $APP/bin/${name})
    '';
  };
}
