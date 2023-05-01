{ config, lib, self, ... }:
let

  file = with config.deployment-TLMS; "${self}/hosts/traffic-stop-box/${toString systemNumber}/config_${toString systemNumber}.json";
  receiver_configs = [
    { frequency = 170795000; offset = 19550; device = "hackrf=0"; RF = 14; IF = 8; BB = 42; } # dresden - barkhausen
    { frequency = 170790000; offset = 20000; device = ""; RF = 14; IF = 32; BB = 42; } # dresden - zentralwerk
    { frequency = 153850000; offset = 20000; device = ""; RF = 14; IF = 32; BB = 42; } # chemnitz
    { frequency = 170795000; offset = 19400; device = ""; RF = 14; IF = 32; BB = 42; } # dresden unused
    { frequency = 170790000; offset = 20000; device = ""; RF = 14; IF = 32; BB = 42; } # dresden Wundstr. 9
    { frequency = 170790000; offset = 20000; device = ""; RF = 14; IF = 32; BB = 42; } # dresden test box
    { frequency = 150827500; offset = 19550; device = ""; RF = 14; IF = 32; BB = 42; } # warpzone münster
    { frequency = 150827500; offset = 19550; device = ""; RF = 14; IF = 32; BB = 42; } # drehturm aachen
    { frequency = 150827500; offset = 20000; device = ""; RF = 14; IF = 32; BB = 42; } # C3H
    { frequency = 152830000; offset = 20000; device = ""; RF = 14; IF = 32; BB = 42; } # Hannover-greater-area
    { frequency = 153850000; offset = 20000; device = ""; RF = 14; IF = 32; BB = 42; } #  CLT
  ];

  receiver_config = lib.elemAt receiver_configs config.deployment-TLMS.systemNumber;
in
{
  TLMS.gnuradio = {
    enable = true;
    frequency = receiver_config.frequency;
    offset = receiver_config.offset;
    device = receiver_config.device;
    RF = receiver_config.RF;
    IF = receiver_config.IF;
    BB = receiver_config.BB;
  };
  TLMS.telegramDecoder = {
    enable = true;
    server = [ "http://10.13.37.1:8080" "http://10.13.37.5:8080" "http://10.13.37.7:8080" ];
    configFile = file;
    authTokenFile = config.sops.secrets.telegram-decoder-token.path;
  };
}
