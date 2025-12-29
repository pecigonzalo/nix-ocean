{
  config,
  pkgs,
  nixpkgs-unstable,
  ...
}:
{
  containers.unifi = {
    autoStart = true;

    macvlans = [ "lan" ];
    privateNetwork = true;
    memoryLimit = "1G";

    config =
      { ... }:
      let
        pkgs-unstable = import nixpkgs-unstable {
          system = pkgs.system;
          config.allowUnfree = true;
        };
      in
      {
        imports = [ ../../common/server-tools.nix ];
        system.stateVersion = "25.05";
        nixpkgs.config.allowUnfree = true;
        networking = {
          useDHCP = false;
          useNetworkd = true;
          useHostResolvConf = false;
          nameservers = [ config.router.services.dns.address ];
        };
        systemd.network = {
          enable = true;
          networks = {
            "lan" = {
              matchConfig.Name = "mv-lan";
              linkConfig.RequiredForOnline = "routable";
              address = [ "${config.router.services.unifi.address}/24" ];
              gateway = [ config.router.lan.address ];
            };
          };
        };
        networking.firewall.allowedTCPPorts = [
          80
          8443
        ];
        services.unifi = {
          enable = true;
          openFirewall = true;
          unifiPackage = pkgs-unstable.unifi;
          mongodbPackage = pkgs-unstable.mongodb-ce;
        };
      };
  };
}
