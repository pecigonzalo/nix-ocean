{
  pkgs,
  ...
}:
let
  blackBoxConfigFormat = pkgs.formats.yaml { };
in
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    configFile = blackBoxConfigFormat.generate "config.yaml" {
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
}
