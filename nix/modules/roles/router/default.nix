{
  lib,
  ...
}:
{
  imports = [
    ./networking.nix
    ./tailscale.nix
    ./dns-dhcp.nix
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
          dnsHosts = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Hostname";
                  };
                  target = lib.mkOption {
                    type = lib.types.str;
                    description = "Target host or IP address";
                  };
                };
              }
            );
            default = [ ];
            description = "Custom DNS host mappings";
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
          dhcpHosts = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Hostname";
                  };
                  ip = lib.mkOption {
                    type = lib.types.str;
                    description = "IP address";
                  };
                  mac = lib.mkOption {
                    type = lib.types.str;
                    description = "MAC address";
                  };
                };
              }
            );
            default = [ ];
            description = "Static DHCP host mappings";
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
