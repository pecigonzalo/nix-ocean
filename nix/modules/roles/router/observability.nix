{
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
      replacement = "127.0.0.1:9115";
    }
  ];
in
{
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
    scrapeConfigs = [
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
        static_configs = [ { targets = [ "127.0.0.1:9115" ]; } ];
      }
    ];
  };
}
