# NixOS configuration for the "mako" router device
# mako: Router and home server
# hardware: Intel N150, 12GB, 512GB SSD
{
  secrets,
  config,
  lib,
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
        address = "192.168.127.5";
        dnsHosts = [
          {
            ip = config.router.lan.address;
            name = "mako";
          }
          {
            ip = config.router.services.dns.address;
            name = "dns";
          }
          {
            ip = config.router.services.dhcp.address;
            name = "dhcp";
          }
          {
            ip = config.router.services.unifi.address;
            name = "control";
          }
          {
            ip = config.router.services.home-assistant.address;
            name = "ha";
          }
          {
            ip = "192.168.127.10";
            name = "beta";
          }
          {
            ip = "192.168.127.11";
            name = "guppy";
          }
          {
            ip = "192.168.127.12";
            name = "tetra";
          }
        ];
      };
      dhcp = {
        enable = true;
        address = "192.168.127.2";
        start = "192.168.127.100";
        end = "192.168.127.200";
        dhcpHosts = [
          {
            mac = "EC:71:DB:D3:53:99";
            ip = "192.168.127.50";
            name = "reolink";
          }
          {
            mac = "78:8A:20:D9:69:1F";
            ip = "192.168.127.22";
            name = "ap-upstairs";
          }
          {
            mac = "24:5A:4C:11:C5:1C";
            ip = "192.168.127.21";
            name = "ap-main";
          }
          {
            mac = "9C:05:D6:F4:E3:3E";
            ip = "192.168.127.20";
            name = "switch";
          }
          {
            mac = "4c:77:cb:e9:a9:76";
            ip = "192.168.127.30";
            name = "beta-wlan";
          }
          {
            mac = "4c:44:5b:89:2e:b1";
            ip = "192.168.127.31";
            name = "guppy-wlan";
          }
          {
            mac = "7c:50:79:23:d8:68";
            ip = "192.168.127.32";
            name = "tetra-wlan";
          }
        ];
      };
      unifi = {
        enable = true;
        address = "192.168.127.250";
      };
      home-assistant = {
        enable = true;
        address = "192.168.127.40";
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
