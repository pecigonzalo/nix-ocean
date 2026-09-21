{
  agenix,
  config,
  lib,
  ...
}:
let
  localDnsNetwork = "home";
in
{
  containers.dns-dhcp = {
    autoStart = true;

    hostBridge = "br-lan";
    privateNetwork = true;
    enableTun = true;

    memoryLimit = "256M";

    bindMounts."/etc/ssh/ssh_host_ed25519_key".isReadOnly = true;

    config =
      { ... }:
      {
        imports = [
          agenix.nixosModules.default
          ../../common/server-tools.nix
        ];
        system.stateVersion = "25.05";

        age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        # Agenix secrets from separate repository
        # NOTE: This is not not nice and its breaking the interface of the module
        age.secrets = {
          tailscale.file = config.age.secrets.tailscale.file;
        };

        networking = {
          useDHCP = false;
          useNetworkd = true;
          useHostResolvConf = false;
          nameservers = config.router.services.dns.upstreams;
        };
        systemd.network = {
          enable = true;
          networks."10-lan" = {
            matchConfig.Name = "eth0";
            linkConfig.RequiredForOnline = "routable";
            address = [
              "${config.router.services.dns.address}/24"
            ]
            ++ lib.optional (
              config.router.services.dns.address6 != null
            ) "${config.router.services.dns.address6}/${toString config.router.lan.prefixLength6}";
            gateway = [ config.router.lan.address ];
          };
        };
        services.resolved.settings.Resolve = {
          # Avoid port conflict with AdGuardHome
          DNSStubListener = false;
        };

        networking.firewall.allowedTCPPorts = [
          53
          80
        ];
        networking.firewall.allowedUDPPorts = [
          53
          67
        ];

        services.tailscale = {
          enable = true;
          extraUpFlags = [ "--accept-dns=false" ];
          extraSetFlags = [ "--accept-dns=false" ];
          authKeyFile = "/run/agenix/tailscale";
        };

        services.dnsmasq =
          let
            toHost = host: "${host.mac},${host.ip},${host.name}";
          in
          {
            enable = config.router.services.dhcp.enable;
            settings = {
              port = 5353;

              dhcp-authoritative = true;
              # IPv4 DHCP only. IPv6 on the LAN is SLAAC via the host's Router
              # Advertisements (see router/networking.nix); dnsmasq must not also
              # emit RAs or a competing/broken prefix would reappear.
              dhcp-range = [
                "${config.router.services.dhcp.start},${config.router.services.dhcp.end},12h"
              ];

              dhcp-option = [
                "option:router,${config.router.lan.address}"
                "option:dns-server,${config.router.services.dns.address}"
              ];
              dhcp-host = map toHost config.router.services.dhcp.dhcpHosts;

              domain-needed = true;
              bogus-priv = true;
              no-resolv = true;

              domain = localDnsNetwork;
              local = "/${localDnsNetwork}/";
              expand-hosts = false;
            };
          };

        services.adguardhome = {
          enable = config.router.services.dns.enable;
          openFirewall = true;
          port = 80;
          allowDHCP = true;
          mutableSettings = false;
          settings = {
            dns = {
              # Serve DNS on IPv4 and IPv6 so clients that received this
              # resolver via IPv6 Router Advertisements (RDNSS) can reach it.
              bind_hosts = [
                "0.0.0.0"
                "::"
              ];
              bootstrap_dns = config.router.services.dns.upstreams;
              upstream_dns = [
                # Unqualified names (single-label DHCP lease hostnames)
                "[//]127.0.0.1:5353"
                "[/${localDnsNetwork}/]127.0.0.1:5353"
              ]
              ++ config.router.services.dns.upstreams;
              upstream_mode = "parallel";

              # Networks treated as private: PTR queries for them resolve via
              # local_ptr_upstreams instead of the public upstreams, so no rDNS
              # info leaks and Tailscale/LAN names come from the right places.
              private_networks = [
                "192.168.127.0/24" # LAN v4 -> dnsmasq
                "100.64.0.0/10" # Tailscale CGNAT v4 -> MagicDNS
                "fd00:1000:1000:1::/64" # LAN ULA v6 -> dnsmasq
                "fd7a:115c:a1e0::/48" # Tailscale ULA v6 -> MagicDNS
              ];
              use_private_ptr_resolvers = true;
              # General fallback -> dnsmasq answers LAN leases/hosts even when
              # Tailscale is down and keeps non-Tailscale PTR traffic away from
              # MagicDNS. dnsproxy requires at least one general (non-scoped)
              # entry and that reserved reverse zones are inside private_networks.
              #
              # Tailscale CGNAT 100.64.0.0/10 spans 64 /16 reverse zones
              # (64.100..127.100.in-addr.arpa), each needs its own rule, hence
              # the generated list below; tailnet v6 is a single zone.
              local_ptr_upstreams =
                map (o: "[/${toString o}.100.in-addr.arpa/]100.100.100.100:53") (lib.range 64 127)
                ++ [
                  "[/0.e.1.a.c.5.1.1.a.7.d.f.ip6.arpa/]100.100.100.100:53"
                  "127.0.0.1:5353"
                ];

              cache_enabled = true;
              cache_size = 256 * 1024; # 256 MB

              hostsfile_enabled = false;
              ratelimit = 0;
            };
            clients = {
              runtime_sources = {
                hosts = false;
              };
            };
            dhcp = {
              enabled = false;
            };
            filtering = {
              blocking_mode = "nxdomain";
              protection_enabled = true;
              filtering_enabled = true;
              parental_enabled = false;
              rewrite_enabled = true;
              rewrites = map (host: {
                answer = host.target;
                domain = "${host.name}";
                type = "A";
                enabled = true;
              }) config.router.services.dns.dnsHosts;
            };
            filters =
              map
                (url: {
                  enabled = true;
                  url = url;
                })
                [
                  "https://adaway.org/hosts.txt"
                  "https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt"
                  "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt"
                  "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
                  "https://lists.cyberhost.uk/malware.txt"
                  "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
                  "https://phishing.army/download/phishing_army_blocklist_extended.txt"
                  "https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts"
                  "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
                  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
                  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
                  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
                  "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
                  "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"
                  "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"
                  "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
                  "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
                  "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
                  "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt"
                  "https://urlhaus.abuse.ch/downloads/hostfile/"
                  "https://v.firebog.net/hosts/AdguardDNS.txt"
                  "https://v.firebog.net/hosts/Admiral.txt"
                  "https://v.firebog.net/hosts/Easylist.txt"
                  "https://v.firebog.net/hosts/Easyprivacy.txt"
                  "https://v.firebog.net/hosts/Prigent-Ads.txt"
                  "https://v.firebog.net/hosts/Prigent-Crypto.txt"
                  "https://v.firebog.net/hosts/RPiList-Malware.txt"
                  "https://v.firebog.net/hosts/static/w3kbl.txt"
                ];
          };
        };
      };
  };
}
