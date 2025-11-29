# Common configuration for all reef cluster nodes
# reef: Reef cluste nodes
# hardware: Intel N150, 12GB, 512GB SSD
{ secrets, config, ... }:
{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/server-tools.nix
    ../../modules/common/users.nix
    ../../modules/roles/n150
    ../../modules/roles/reef-node
  ];

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
  };
}
