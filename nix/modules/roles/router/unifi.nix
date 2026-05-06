{
  config,
  pkgs-unstable,
  ...
}:
{
  containers.unifi = {
    autoStart = true;

    macvlans = [ "lan" ];
    privateNetwork = true;
    memoryLimit = "1G";
    specialArgs = {
      inherit pkgs-unstable;
    };

    config =
      {
        pkgs-unstable,
        ...
      }:
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
          networks."10-lan" = {
            matchConfig.Name = "mv-lan";
            linkConfig.RequiredForOnline = "routable";
            address = [ "${config.router.services.unifi.address}/24" ];
            gateway = [ config.router.lan.address ];
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
          # FCV was migrated to 8.0 on 2026-05-06; keep Mongo on mongodb-ce (8.x).
          mongodbPackage = pkgs-unstable.mongodb-ce;
          jrePackage = pkgs-unstable.jdk25_headless;
        };
      };
  };
}
