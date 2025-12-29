{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./networking.nix
    ./k3s.nix
  ];

  options = {
    reefNode = {
      wlan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "WAN WiFi interface MAC address";
          example = "e0:51:d8:1b:dd:08";
        };
        ssid = lib.mkOption {
          type = lib.types.str;
          description = "WAN WiFi SSID";
          example = "MyNetwork";
        };
        pskFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to iwd PSK configuration file.
            Should be in iwd's PSK format:
            [Security]
            Passphrase=your-wifi-password

            Typically provided via agenix secret path.
          '';
          example = "/run/agenix/iwd-network";
        };
      };
      lan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "LAN interface MAC address";
          example = "e0:51:d8:1b:dd:07";
        };
        address = lib.mkOption {
          type = lib.types.str;
          description = "LAN IP address";
          example = "192.168.127.10";
        };
        prefixLength = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "LAN prefix length";
        };
        defaultGateway = lib.mkOption {
          type = lib.types.str;
          description = "LAN default gateway";
          example = "192.168.127.254";
        };
        nameserver = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "LAN nameserver(s)";
          example = [ "192.168.127.5" ];
        };
      };
    };
  };

  config =
    # Base configuration (always enabled)
    {
      environment.systemPackages = with pkgs; [
        tailscale
        iw
        wirelesstools
      ];
      services.irqbalance.enable = false;
    };
}
