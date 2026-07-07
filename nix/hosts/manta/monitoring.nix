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
  services.alloy = {
    enable = true;
    extraFlags = [
      "--server.http.listen-addr=127.0.0.1:12345"
    ];
  };

  environment.etc."alloy/config.alloy".text = ''
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal__boot_id"]
        target_label  = "boot_id"
      }

      rule {
        source_labels = ["__journal__transport"]
        target_label  = "transport"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }

    loki.source.journal "journal" {
      forward_to    = [loki.write.grafana_cloud.receiver]
      relabel_rules = loki.relabel.journal.rules
      max_age       = "24h"
      labels        = {
        job      = "integrations/node_exporter",
        instance = "${config.networking.hostName}",
      }
    }

    loki.write "grafana_cloud" {
      endpoint {
        url = "https://logs-prod-eu-west-0.grafana.net/api/prom/push"

        basic_auth {
          username      = "279341"
          password_file = "/run/credentials/alloy.service/grafana-logs-token"
        }
      }
    }
  '';

  systemd.services.alloy.serviceConfig = {
    LoadCredential = "grafana-logs-token:${config.age.secrets.grafana-logs-token.path}";
    SupplementaryGroups = [
      "adm"
      "systemd-journal"
    ];
  };
}
