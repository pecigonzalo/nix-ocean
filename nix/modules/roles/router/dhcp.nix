{
  config,
  lib,
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
        networking.firewall.allowedUDPPorts = [ 67 ];
        services.dnsmasq =
          let
            toHost = host: "dhcp-host=${host.mac},${host.ip},${host.name}";
          in
          {
            enable = config.router.services.dhcp.enable;
            settings = {
              interface = "mv-lan";
              dhcp-range = "${config.router.services.dhcp.start},${config.router.services.dhcp.end},12h";
              dhcp-option = [
                "option:router,${config.router.lan.address}"
                "option:dns-server,${config.router.services.dns.address}"
              ];
              dhcp-hosts = map toHost config.router.services.dhcp.dhcpHosts;
              domain = "lan";
              expand-hosts = true;
              listen-address = [
                "127.0.0.1"
                config.router.services.dhcp.address
              ];
            };
          };
      };
  };
}
