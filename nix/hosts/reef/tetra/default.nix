# NixOS configuration for reef beta node
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../default.nix # Common reef config
  ];

  networking.hostName = "tetra";

  reefNode = {
    wlan = {
      mac = "7c:50:79:23:d8:68";
    };
    lan = {
      mac = "e0:51:d8:1a:f2:b1";
      address = "192.168.127.12";
      prefixLength = 24;
      defaultGateway = "192.168.127.254";
      nameserver = [ "192.168.127.5" ];
    };
  };

  # State version
  system.stateVersion = "24.05";
}
