{ config, ... }:
{
  TLMS.trekkie = {
    enable = true;
    host = "0.0.0.0";
    saltPath = config.sops.secrets.postgres_password_hash_salt.path;
    port = 8060;
    database = {
      host = "127.0.0.1";
      port = config.services.postgresql.port;
      passwordFile = config.sops.secrets.postgres_password.path;
      user = "tlms";
    };
    redis = {
      port = 6379;
      host = "localhost";
    };
    logLevel = "info";
  };
  systemd.services."trekkie" = {
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
  };

  services = {
    redis.servers."trekkie" = {
      enable = true;
      bind = config.TLMS.trekkie.redis.host;
      port = config.TLMS.trekkie.redis.port;
    };

    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "trekkie.${config.deployment-TLMS.domain}" = {
          forceSSL = true;
          enableACME = true;
          locations = {
            "/" = {
              proxyPass = with config.TLMS.trekkie; "http://${host}:${toString port}/";
            };
          };
        };
      };
    };
  };
}
