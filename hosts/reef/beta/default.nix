{ secrets, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../default.nix # Common reef config
  ];

  networking.hostName = "beta";

  age.secrets = {
    wifi-password = {
      file = "${secrets}/wifi-password.age";
      owner = "root";
      group = "root";
      mode = "400";
    };
  };

  reefNode = {
    wlan = {
      ssid = "DavyJones IoT";
      nmEnvironmentFile = config.age.secrets.wifi-password.path;
    };
    lan = {
      mac = "e0:51:d8:1b:dd:07";
      address = "192.168.127.10";
      prefixLength = 24;
      defaultGateway = "192.168.127.254";
      nameserver = [ "192.168.127.254" ];
    };
  };
}
