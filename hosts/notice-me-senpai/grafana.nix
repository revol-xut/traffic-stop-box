{ config, lib, self, registry, ... }:
let
  grafana_host = "grafana.tlm.solutions";
in
{
  # rules for public interface, ddvb-wg is considered trusted, no firewall there
  networking.firewall = {
    allowedTCPPorts = [
      80 # nginx
      443 # nginx
    ];
    allowedUDPPorts = [
    ];
  };
  services = {
    # metrics collector
    prometheus =
      {
        enable = true;
        port = 9501;
        listenAddress = registry.wgAddr4;
        globalConfig = {
          scrape_interval = "131s";
        };
        scrapeConfigs =
          let
            ### Autogenerate prometheus scraper config
            # currently only wireguard-connected machines are getting scraped.
            filterWgHosts = k: v: !(builtins.isNull v._module.specialArgs.registry.wgAddr4);
            wgHosts = lib.filterAttrs filterWgHosts self.nixosConfigurations;

            # collect active prometheus exporters
            filterEnabledExporters = name: host: lib.filterAttrs (k: v: (builtins.isAttrs v) && v.enable == true) host.config.services.prometheus.exporters;
            enabledExporters = lib.mapAttrs filterEnabledExporters wgHosts;

            # turns exporter config into scraper config
            makeScrapeConfig = hostname: exporter: exporter-cfg: {
              job_name = "${hostname}_${exporter}";
              static_configs =
                let
                  ip = wgHosts."${hostname}"._module.specialArgs.registry.wgAddr4;
                in
                [{
                  targets = [ "${ip}:${toString exporter-cfg.port}" ];
                }];

              relabel_configs = [
                {
                  target_label = "instance";
                  replacement = "${hostname}";
                }
                {
                  target_label = "job";
                  replacement = "${exporter}";
                }
              ];
            };

            # generate scraper config
            makeScrapeConfigHost = name: exporters: lib.mapAttrs (makeScrapeConfig name) exporters;
            ScrapeConfigByHost = lib.mapAttrs makeScrapeConfigHost enabledExporters;

            TLMSScrapeConfigs = lib.lists.flatten (map lib.attrValues (lib.attrValues ScrapeConfigByHost));
          in
          TLMSScrapeConfigs ++ [
            {
              job_name = "funnel-connections-prod";
              static_configs = [{
                targets = [ "10.13.37.1:10012" ];
              }];
            }
            {
              job_name = "funnel-connections-staging";
              static_configs = [{
                targets = [ "10.13.37.5:10012" ];
              }];
            }
          ];
      };
    # log collector
    loki = {
      enable = true;
      configuration = {
        server.http_listen_port = registry.port-loki;
        auth_enabled = false;

        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
          };
          chunk_idle_period = "1h";
          max_chunk_age = "1h";
          chunk_target_size = 1048576;
          chunk_retain_period = "30s";
          max_transfer_retries = 0;
        };

        schema_config = {
          configs = [{
            from = "2022-05-05";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }];
        };

        storage_config = {
          boltdb_shipper = {
            active_index_directory = "/var/lib/loki/boltdb-shipper-active";
            cache_location = "/var/lib/loki/boltdb-shipper-cache";
            cache_ttl = "48h";
            shared_store = "filesystem";
          };
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };

        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        chunk_store_config = {
          max_look_back_period = "0s";
        };

        table_manager = {
          retention_deletes_enabled = true;
          retention_period = "720h";
        };

        compactor = {
          working_directory = "/var/lib/loki";
          compaction_interval = "10m";
          retention_enabled = true;
          retention_delete_delay = "1m";
          shared_store = "filesystem";
          compactor_ring = {
            kvstore = {
              store = "inmemory";
            };
          };
        };
      };
    };

    # visualizer/alerting
    grafana = {
      enable = true;
      settings.server = {
        domain = grafana_host;
        http_addr = "127.0.0.1";
        http_port = 2342;
      };
    };

    # grafana reverse proxy
    nginx =
      let
        headers = ''
          # Permissions Policy - gps only
          add_header Permissions-Policy "geolocation=()";

          # Minimize information leaked to other domains
          add_header 'Referrer-Policy' 'origin-when-cross-origin';

          # Disable embedding as a frame
          add_header X-Frame-Options DENY;

          # Prevent injection of code in other mime types (XSS Attacks)
          add_header X-Content-Type-Options nosniff;

          # Enable XSS protection of the browser.
          # May be unnecessary when CSP is configured properly (see above)
          add_header X-XSS-Protection "1; mode=block";

          # STS
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        '';
      in
      {
        enable = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;
        commonHttpConfig = headers;

        virtualHosts = {
          "${grafana_host}" = {
            enableACME = true;
            forceSSL = true;
            locations."/" =
              let
                g = config.services.grafana.settings.server;
              in
              {
                proxyPass = "http://${g.http_addr}:${toString g.http_port}";
                proxyWebsockets = true;
                extraConfig = ''
                  proxy_set_header Host $host;
                '';
              };
          };
        };
      };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "TLMS@protonmail.com";
}
