{ modulesPath, ... }:
{
  imports = [
    ./hardware-configuration.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/users.nix
    ../../modules/roles/reef-node.nix
  ];

  networking.hostName = "manta";

  reefNode = {
    lan = {
      mac = "00:00:00:00:00:00"; # TODO: Set actual MAC address
      address = "192.168.127.13";
      prefixLength = 24;
      defaultGateway = "192.168.127.254";
      nameserver = [ "192.168.127.254" ];
    };
  };
}
