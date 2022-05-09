{ pkgs, config, lib, ... }: {
  services = {
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
        "map.dvb.solutions" = {
          enableACME = true;
          onlySSL = true;
          locations = {
            "/" = {
              root = "${pkgs.windshield}/bin/";
              index = "index.html";
            };
          };
        };
      };
    };
  };
}
