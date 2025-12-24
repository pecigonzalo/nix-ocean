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
              address = [ "${config.router.services.dhcp.address}/24" ];
              gateway = [ config.router.lan.address ];
            };
          };
        };
        services.resolved = {
          # Avoid port conflict with AdGuardHome
          extraConfig = ''
            DNSStubListener=no
          '';
        };
        networking.firewall.allowedTCPPorts = [ 53 ];
        networking.firewall.allowedUDPPorts = [
          67
          53
        ];
        services.dnsmasq =
          let
            toHost = host: "${host.mac},${host.ip},${host.name}";
          in
          {
            enable = config.router.services.dhcp.enable;
            # resolveLocalQueries = true;
            settings = {
              interface = "mv-lan";

              dhcp-authoritative = true;
              dhcp-range = "${config.router.services.dhcp.start},${config.router.services.dhcp.end},12h";
              dhcp-option = [
                "option:router,${config.router.lan.address}"
                "option:dns-server,${config.router.services.dns.address}"
              ];
              dhcp-host = map toHost config.router.services.dhcp.dhcpHosts;

              domain-needed = true;
              domain = "home";
              local = "/home/";
              expand-hosts = true;
              no-resolv = true;
              server = config.router.services.dns.upstreams;
            };
          };
      };
  };
}
