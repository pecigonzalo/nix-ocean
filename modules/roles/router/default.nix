{
  lib,
  ...
}:
{
  imports = [
    ./networking.nix
    ./tailscale.nix
    ./services.nix
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
        authKey = lib.mkOption {
          type = lib.types.str;
          description = "Tailscale auth key";
        };
        routes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Routes to advertise";
        };
      };
      services = {
        pihole = {
          enable = lib.mkEnableOption "Pi-hole DNS and DHCP server";
          password = lib.mkOption {
            type = lib.types.str;
            description = "Pi-hole web interface password";
          };
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
