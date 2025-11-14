{ modulesPath, config, secrets, ... }:
{
  imports = [
    ./hardware-configuration.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/common/disko.nix
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/users.nix
    ../../modules/roles/router.nix
  ];

  networking.hostName = "mako";

  # Agenix secrets from separate repository
  age.secrets = {
    tailscale-key = {
      file = "${secrets}/tailscale-mako.age";
      owner = "root";
      group = "root";
      mode = "400";
    };
    pihole-password = {
      file = "${secrets}/pihole-password.age";
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
      authKey = "tskey-auth-k4tpnX4K9y11CNTRL-FFmGQ3TYKpYqBpJSQ8CbvYC4HSu3rvZAj";
      routes = [ "192.168.127.0/24" ];
    };
    services = {
      pihole = {
        enable = true;
        password = "ABC123abc!";
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
}
