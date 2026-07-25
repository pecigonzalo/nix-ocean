{
  agenix,
  config,
  pkgs-unstable,
  ...
}:
{
  containers.home-assistant = {
    autoStart = true;

    hostBridge = "br-lan";
    privateNetwork = true;
    enableTun = true;
    specialArgs = {
      inherit pkgs-unstable;
    };

    memoryLimit = "1G";

    # Mount Zigbee USB device
    bindMounts = {
      "/etc/ssh/ssh_host_ed25519_key".isReadOnly = true;
      "/dev/zigbee" = {
        hostPath = config.router.services.home-assistant.zigbeeDevice;
        isReadOnly = false;
      };
      "/dev/net/tun" = {
        hostPath = "/dev/net/tun";
        isReadOnly = false;
      };
    };
    allowedDevices = [
      {
        node = "/dev/ttyUSB0";
        modifier = "rwm";
      }
      {
        node = "/dev/net/tun";
        modifier = "rwm";
      }
    ];

    config =
      { pkgs-unstable, ... }:
      {
        imports = [
          agenix.nixosModules.default
          ../../common/server-tools.nix
        ];
        system.stateVersion = "25.05";

        age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        # Agenix secrets from separate repository
        # NOTE: This is not not nice and its breaking the interface of the module
        age.secrets = {
          tailscale.file = config.age.secrets.tailscale.file;
        };

        networking = {
          useDHCP = false;
          useNetworkd = true;
          useHostResolvConf = false;
          nameservers = [ config.router.services.dns.address ];
        };

        systemd.network = {
          enable = true;
          networks."10-lan" = {
            matchConfig.Name = "eth0";
            linkConfig.RequiredForOnline = "routable";
            address = [
              "${config.router.services."home-assistant".address}/24"
              "fd00:1000:1000:1::10/64"
            ];
            gateway = [ config.router.lan.address ];
          };
        };

        services.tailscale = {
          enable = true;
          extraUpFlags = [ "--accept-dns=false" ];
          extraSetFlags = [ "--accept-dns=false" ];
          authKeyFile = "/run/agenix/tailscale";
        };

        # Home Assistant runs its own zeroconf mDNS stack for discovery.
        # matter-server now lives in its own container (see matter.nix).
        networking.firewall.allowedUDPPorts = [ 5353 ];

        users.users.hass.extraGroups = [ "dialout" ];
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
            "thread"
            "otbr"
            "mobile_app"
            "sun"
            "telegram_bot"
            "wiz"
            "time_date"
            "home_connect"
            "roborock"
            "reolink"
            "cast"
            "apple_tv"
            "androidtv_remote"
          ];
          customComponents = with pkgs-unstable.home-assistant-custom-components; [
            alarmo
          ];
          config = {
            default_config = { };

            frontend = {
              themes = "!include_dir_merge_named themes";
            };

            automation = "!include automations.yaml";
            script = "!include scripts.yaml";
            scene = "!include scenes.yaml";

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

      };
  };
}
