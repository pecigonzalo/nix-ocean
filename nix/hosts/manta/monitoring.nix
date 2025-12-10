{ config, ... }: {
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
        job_name = "node";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }];
        relabel_configs = [
          { replacement = config.networking.hostName; target_label = "instance"; }
        ];
      }
      {
        job_name = "cadvisor";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.cadvisor.port}" ];
        }];
      }
    ];
    remoteWrite = [
      {
        url = "https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push";
        basic_auth = {
          username = "560743";
          password = "glc_eyJvIjoiNzA0NjUxIiwibiI6InN0YWNrLTQyOTk4Ny1pbnRlZ3JhdGlvbi1uaXhmaXNoLXByb21ldGhldXMtbml4ZmlzaC1wcm9tZXRoZXVzIiwiayI6Imc4bjJTNDlCWjh3Mnc0NjhTVHI2VFdUTiIsIm0iOnsiciI6ImV1In19";
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
        url = "https://279341:glc_eyJvIjoiNzA0NjUxIiwibiI6InN0YWNrLTQyOTk4Ny1pbnRlZ3JhdGlvbi1uaXhmaXNoLWxvZ3Mtbml4ZmlzaC1sb2dzIiwiayI6Ims3M0xIMTB1ODhhS2RlOEc0Nm83c0xZSyIsIm0iOnsiciI6ImV1In19@logs-prod-eu-west-0.grafana.net/api/prom/push";
      };

      scrape_configs = [{
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
      }];
    };
  };
}
