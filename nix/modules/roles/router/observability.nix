{
  config,
  pkgs,
  ...
}:
let
  blackboxConfigFormat = pkgs.formats.yaml { };
  blackboxRelabelConfigs = [
    {
      source_labels = [ "__address__" ];
      target_label = "__param_target";
    }
    {
      source_labels = [ "__param_target" ];
      target_label = "instance";
    }
    {
      target_label = "__address__";
      # Blackbox exporter real hostname:port.
      replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
    }
  ];
in
{
  services.grafana = {
    enable = true;

    settings = {
      server.http_addr = config.router.lan.address;

      "auth.anonymous" = {
        enabled = true;
        org_role = "Viewer";
      };

      analytics.reporting_enabled = false;
    };

    provision = {
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:${toString config.services.prometheus.port}";
          isDefault = true;
        }
      ];
    };
  };
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [
      "systemd"
      "diskstats"
      "filesystem"
      "loadavg"
      "meminfo"
      "netdev"
      "stat"
      "time"
      "uname"
    ];
  };
  services.prometheus.exporters.blackbox = {
    enable = true;
    configFile = blackboxConfigFormat.generate "config.yaml" {
      modules = {
        http_2xx = {
          prober = "http";
          timeout = "1s";
        };
        icmp = {
          prober = "icmp";
          timeout = "1s";
          icmp = {
            preferred_ip_protocol = "ip4";
          };
        };
      };
    };
  };
  services.prometheus = {
    enable = true;
    retentionTime = "30d";

    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    scrapeConfigs = [
      {
        job_name = "node_exporter";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
      {
        job_name = "blackbox_icmp";
        metrics_path = "/probe";
        scrape_interval = "1s";
        params = {
          module = [ "icmp" ];
        };
        static_configs = [
          {
            targets = [
              "ssh.munin.xyz"
              "192.168.1.1"
              "1.1.1.1"
              "8.8.8.8"
              "192.168.127.20"
            ];
          }
        ];
        relabel_configs = blackboxRelabelConfigs;
      }
      {
        job_name = "blackbox_http";
        metrics_path = "/probe";
        scrape_interval = "1s";
        params = {
          module = [ "http_2xx" ];
        };
        static_configs = [
          {
            targets = [
              "ssh.munin.xyz"
            ];
          }
        ];
        relabel_configs = blackboxRelabelConfigs;

      }
      {
        job_name = "blackbox_exporter";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}" ]; }
        ];
      }
    ];
  };
}
