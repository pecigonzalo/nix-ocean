{
  lib,
  ...
}:
{
  imports = [
    ./networking.nix
    ./tailscale.nix
    ./services.nix
    ./dns.nix
    ./unifi.nix
    ./home-assistant.nix
  ];

  options = {
    router = {
      wan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "WAN interface MAC address";
        };
        address = lib.mkOption {
          type = lib.types.str;
          description = "WAN static IP address";
        };
        prefixLength = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "WAN prefix length";
        };
      };
      lan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "LAN interface MAC address";
        };
        address = lib.mkOption {
          type = lib.types.str;
          description = "LAN IP address";
        };
        prefixLength = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "LAN prefix length";
        };
      };
      tailscale = {
        routes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Routes to advertise";
        };
        authKeyFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to Tailscale auth key file";
        };
      };
      services = {
        dns = {
          enable = lib.mkEnableOption "Enable DNS service";
          address = lib.mkOption {
            type = lib.types.str;
          };
          upstreams = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "1.1.1.1"
              "8.8.8.8"
            ];
          };
        };
        dhcp = {
          enable = lib.mkEnableOption "Enable DHCP service";
          start = lib.mkOption {
            type = lib.types.str;
            description = "DHCP range start address";
          };
          end = lib.mkOption {
            type = lib.types.str;
            description = "DHCP range end address";
          };
        };
        unifi = {
          enable = lib.mkEnableOption "Enable Unifi service";
          address = lib.mkOption {
            type = lib.types.str;
            description = "Unifi controller address";
          };
        };
        home-assistant = {
          enable = lib.mkEnableOption "Enable HomeAssistant service";
          address = lib.mkOption {
            type = lib.types.str;
            description = "Unifi controller address";
          };
        };
        pihole = {
          enable = lib.mkEnableOption "Pi-hole DNS and DHCP server";
          dhcpRange = {
            start = lib.mkOption {
              type = lib.types.str;
              description = "DHCP range start address";
            };
            end = lib.mkOption {
              type = lib.types.str;
              description = "DHCP range end address";
            };
          };
          dhcpHosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Static DHCP host mappings (MAC,IP,NAME)";
          };
          dnsHosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Custom DNS host mappings (NAME IP)";
          };
          upstreams = lib.mkOption {
            type = lib.types.str;
            default = "1.1.1.1;8.8.8.8";
            description = "Upstream DNS servers";
          };
          secretsFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to secrets file to mount in pihole";
          };
        };
        homeAssistant = {
          enable = lib.mkEnableOption "Home Assistant";
          zigbeeDevice = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Zigbee USB device path";
          };
        };
      };
    };
  };
}
