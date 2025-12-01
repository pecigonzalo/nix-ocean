# Common configuration for all reef cluster nodes
# reef: Reef cluster nodes
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

  # Agenix secret for iwd wireless configuration
  age.secrets.iwd-davyjones-iot = {
    file = "${secrets}/iwd-davyjones-iot.age";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  reefNode = {
    wlan = {
      ssid = "DavyJones IoT";
      pskFile = config.age.secrets.iwd-davyjones-iot.path;
    };
  };
}
