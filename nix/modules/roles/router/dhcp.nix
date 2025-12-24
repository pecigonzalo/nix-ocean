{
  config,
  ...
}:
{
  containers.dhcp = {
    autoStart = true;

    macvlans = [ "lan" ];
    privateNetwork = true;
    memoryLimit = "256M";

    config =
      { ... }:
      {
        imports = [ ../../common/server-tools.nix ];
        system.stateVersion = "25.05";
        networking = {
          useDHCP = false;
          useNetworkd = true;
          useHostResolvConf = false;
          nameservers = config.router.services.dns.upstreams;
        };
        systemd.network = {
          enable = true;
          networks = {
            "lan" = {
              matchConfig.Name = "mv-lan";
              linkConfig.RequiredForOnline = "routable";
              address = [ config.router.services.dhcp.address ];
              gateway = [ config.router.lan.address ];
            };
          };
        };
        services.dnsmasq = {
          enable = true;
          settings = {
            domain = "home";
          };
        };
      };
  };
}
