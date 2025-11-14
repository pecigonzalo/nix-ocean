{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../default.nix  # Common reef config
  ];

  networking.hostName = "beta";

  reefNode = {
    lan = {
      mac = "e0:51:d8:1b:dd:07";
      address = "192.168.127.10";
      prefixLength = 24;
      defaultGateway = "192.168.127.254";
      nameserver = [ "192.168.127.254" ];
    };
  };
}
