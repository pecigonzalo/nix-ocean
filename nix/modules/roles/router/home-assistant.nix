{
  config,
  ...
}:
{
  containers.home-assistant = {
    autoStart = true;

    macvlans = [ "lan" ];
    privateNetwork = true;
    memoryLimit = "1G";

    config =
      { ... }:
      {
        imports = [ ../../common/server-tools.nix ];
        system.stateVersion = "25.05";
        networking = {
          useDHCP = false;
          useNetworkd = true;
          useHostResolvConf = false;
          nameservers = config.router.services.dns.upstreams;
        };
        systemd.network = {
          enable = true;
          networks = {
            "lan" = {
              matchConfig.Name = "mv-lan";
              linkConfig.RequiredForOnline = "routable";
              address = [ "${config.router.services.home-assistant.address}/24" ];
              gateway = [ config.router.lan.address ];
            };
          };
        };

        services.home-assistant = {
          enable = true; # config.router.services.home-assistant.enable;
          openFirewall = true;
          extraComponents = [
            "default_config"
            "met"
            "esphome"
            "isal"
            "zha"

            # Onboarding
            "analytics"
            "google_translate"
            "radio_browser"
            "shopping_list"
          ];
          config = {
            default_config = { };

            frontend = {
              themes = "!include_dir_merge_named themes";
            };

            automation = "!include /etc/home-assistant/automations.yaml";
            script = "!include /etc/home-assistant/scripts.yaml";
            scene = "!include /etc/home-assistant/scenes.yaml";

            homeassistant = {
              name = "home";
              unit_system = "metric";
              time_zone = "Europe/Madrid";

              external_url = "https://ha.munin.xyz";
              internal_url = "http://mako.local:8123";
            };
            http = {
              use_x_forwarded_for = true;
              trusted_proxies = [
                "100.111.119.44/32"
              ];
            };
          };
        };
      };
  };
}
