# NixOS configuration for the "mako" router device
# mako: Router and home server
# hardware: Intel N150, 12GB, 512GB SSD
{
  secrets,
  config,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/server-tools.nix
    ../../modules/common/users.nix
    ../../modules/common/containers.nix
    ../../modules/roles/n150
    ../../modules/roles/router
  ];

  networking.hostName = "mako";

  # Agenix secrets from separate repository
  age.secrets = {
    tailscale = {
      file = "${secrets}/tailscale.age";
      owner = "root";
      group = "root";
      mode = "400";
    };
    pihole = {
      file = "${secrets}/pihole.age";
      owner = "root";
      group = "root";
      mode = "400";
    };
  };

  # Router configuration
  router = {
    wan = {
      mac = "e0:51:d8:1c:37:41";
      address = "192.168.1.10";
      prefixLength = 24;
    };
    lan = {
      mac = "e0:51:d8:1c:37:42";
      address = "192.168.127.254";
      prefixLength = 24;
    };
    tailscale = {
      authKeyFile = config.age.secrets.tailscale.path;
      routes = [ "192.168.127.0/24" ];
    };
    services = {
      dns = {
        enable = true;
        address = "192.168.127.25/24";
      };
      dhcp = {
        enable = false;
        start = "192.168.127.100";
        end = "192.168.127.200";
      };
      unifi = {
        enable = true;
        address = "192.168.127.250/24";
      };
      home-assistant = {
        enable = true;
        address = "192.168.127.40/24";
      };
      pihole = {
        enable = true;
        secretsFile = config.age.secrets.pihole.path;
        dhcpRange = {
          start = "192.168.127.100";
          end = "192.168.127.200";
        };
        dhcpHosts = [
          "EC:71:DB:D3:53:99,192.168.127.50,reolink"
          "78:8A:20:D9:69:1F,192.168.127.22,ap-upstairs"
          "24:5A:4C:11:C5:1C,192.168.127.21,ap-main"
          "9C:05:D6:F4:E3:3E,192.168.127.20,switch"
          "4c:77:cb:e9:a9:76,192.168.127.30,beta-wlan"
          "4c:44:5b:89:2e:b1,192.168.127.31,guppy-wlan"
          "7c:50:79:23:d8:68,192.168.127.32,tetra-wlan"
        ];
        dnsHosts = [
          "192.168.127.10 beta"
          "192.168.127.11 guppy"
          "192.168.127.12 tetra"
        ];
      };
      homeAssistant = {
        enable = true;
        zigbeeDevice = "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20240217171220-if00";
      };
    };
  };

  # State version
  system.stateVersion = "24.05";
}
