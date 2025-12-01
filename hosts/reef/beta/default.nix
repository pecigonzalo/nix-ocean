# NixOS configuration for reef beta node
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../default.nix # Common reef config
  ];

  networking.hostName = "beta";

  reefNode = {
    wlan = {
      mac = "4c:77:cb:e9:a9:76";
    };
    lan = {
      mac = "e0:51:d8:1b:dd:07";
      address = "192.168.127.10";
      prefixLength = 24;
      defaultGateway = "192.168.127.254";
      nameserver = [ "192.168.127.254" ];
    };
  };

  # State version
  system.stateVersion = "24.05";
}
