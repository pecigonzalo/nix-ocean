# NixOS configuration for reef beta node
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../default.nix # Common reef config
  ];

  networking.hostName = "guppy";

  reefNode = {
    lan = {
      mac = "e0:51:d8:1a:94:f6";
      address = "192.168.127.11";
      prefixLength = 24;
      defaultGateway = "192.168.127.254";
      nameserver = [ "192.168.127.254" ];
    };
  };

  # State version
  system.stateVersion = "24.05";
}
