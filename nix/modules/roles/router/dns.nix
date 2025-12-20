{
  config,
  ...
}:
{
  containers.dns = {
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
              address = [ config.router.services.dns.address ];
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
        networking.firewall.allowedTCPPorts = [
          53
          80
        ];
        networking.firewall.allowedUDPPorts = [ 53 ];
        services.adguardhome = {
          enable = config.router.services.dns.enable;
          openFirewall = true;
          port = 80;
          allowDHCP = true;
          mutableSettings = false;
          settings = {
            dns = {
              bootstrap_dns = config.router.services.dns.upstreams;
              upstream_dns = config.router.services.dns.upstreams;
            };
            dhcp = {
              enabled = false;
              dhcpv4 = {
                gateway_ip = config.router.lan.address;
                subnet_mask = "255.255.255.0";
                range_start = config.router.services.dhcp.start;
                range_end = config.router.services.dhcp.end;
              };
              local_domain_name = "lan";
            };
            filtering = {
              protection_enabled = true;
              filtering_enabled = true;
              parental_enabled = false;
            };
            filters =
              map
                (url: {
                  enabled = true;
                  url = url;
                })
                [
                  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
                ];
          };
        };
      };
  };
}
