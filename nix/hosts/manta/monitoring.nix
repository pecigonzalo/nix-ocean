{ config, ... }:
{
  services.cadvisor = {
    enable = true;
    port = 9101;
    extraOptions = [
      "--docker_only=true"
    ];
  };
  services.prometheus = {
    enable = true;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
      };
    };
    scrapeConfigs = [
      {
        job_name = "integrations/node_exporter";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
        relabel_configs = [
          {
            replacement = config.networking.hostName;
            target_label = "instance";
          }
        ];
      }
      {
        job_name = "integrations/docker";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.cadvisor.port}" ];
          }
        ];
      }
    ];
    remoteWrite = [
      {
        url = "https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push";
        basic_auth = {
          username = "560743";
          password_file = config.age.secrets.grafana-prometheus-token.path;
        };
      }
    ];
  };
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 0;
        grpc_listen_port = 0;
      };

      client = {
        url = "https://logs-prod-eu-west-0.grafana.net/api/prom/push";
        basic_auth = {
          username = "279341";
          password_file = config.age.secrets.grafana-logs-token.path;
        };
      };

      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "24h";
            labels = {
              job = "integrations/node_exporter";
              instance = "hostname";
            };
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
            {
              source_labels = [ "__journal__boot_id" ];
              target_label = "boot_id";
            }
            {
              source_labels = [ "__journal__transport" ];
              target_label = "transport";
            }
            {
              source_labels = [ "__journal_priority_keyword" ];
              target_label = "level";
            }
          ];
        }
      ];
    };
  };
}
