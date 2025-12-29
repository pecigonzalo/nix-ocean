{
  config,
  lib,
  pkgs,
  nixpkgs-unstable,
  ...
}:
{
  containers.home-assistant = {
    autoStart = true;

    macvlans = [ "lan" ];
    privateNetwork = true;
    memoryLimit = "1G";

    # Mount Zigbee USB device
    bindMounts = lib.optionalAttrs (config.router.services.home-assistant.zigbeeDevice != null) {
      "/dev/ttyACM0" = {
        hostPath = config.router.services.home-assistant.zigbeeDevice;
        isReadOnly = false;
      };
    };
    allowedDevices = [
      {
        node = "/dev/ttyACM0";
        modifier = "rwm";
      }
    ];

    config =
      { ... }:
      let
        pkgs-unstable = import nixpkgs-unstable {
          system = pkgs.system;
          config.allowUnfree = true;
        };
      in
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
              address = [ "${config.router.services."home-assistant".address}/24" ];
              gateway = [ config.router.lan.address ];
            };
          };
        };

        services.home-assistant = {
          enable = config.router.services."home-assistant".enable;
          package = pkgs-unstable.home-assistant;
          openFirewall = true;
          extraComponents = [
            # Default
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

            # Custom
            "matter"
            "mobile_app"
            "sun"
            "telegram_bot"
            "wiz"
            "time_date"
            "home_connect"
            "roborock"
            "reolink"
            "cast"
          ];
          customComponents = with pkgs-unstable.home-assistant-custom-components; [
            alarmo
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
              internal_url = "http://ha.home:8123";
            };
            http = {
              use_x_forwarded_for = true;
              trusted_proxies = [
                "100.111.119.44/32"
              ];
            };
          };
        };

        services.matter-server = {
          enable = true;
        };
      };
  };
}
