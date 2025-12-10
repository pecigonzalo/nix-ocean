{
  config,
  lib,
  ...
}:
{
  # Disable NetworkManager in favor of systemd-networkd + iwd
  networking.networkmanager.enable = lib.mkForce false;

  # Enable systemd-networkd
  systemd.network.enable = true;
  networking.useNetworkd = true;
  networking.useDHCP = false;

  # Enable iwd for wireless networking
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.EnableNetworkConfiguration = false;
      Network = {
        EnableIPv6 = false;
        RoutePriorityOffset = 100;
      };
    };
  };

  # Symlink iwd network configuration
  # Escape spaces in SSID for tmpfiles (uses \x20 for spaces)
  systemd.tmpfiles.rules = [
    "L+ /var/lib/iwd/${
      lib.replaceStrings [ " " ] [ "\\x20" ] config.reefNode.wlan.ssid
    }.psk - - - - ${config.reefNode.wlan.pskFile}"
  ];

  # Rename LAN interface based on MAC address
  systemd.network.links."10-lan" = {
    matchConfig.PermanentMACAddress = config.reefNode.lan.mac;
    linkConfig.Name = "lan";
  };
  systemd.network.links."20-wlan" = {
    matchConfig.PermanentMACAddress = config.reefNode.wlan.mac;
    linkConfig.Name = "wlan";
  };

  # Wired LAN interface - static configuration (primary)
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "lan";
    linkConfig.RequiredForOnline = "routable";
    address = [ "${config.reefNode.lan.address}/${toString config.reefNode.lan.prefixLength}" ];
    gateway = [ config.reefNode.lan.defaultGateway ];
    dns = config.reefNode.lan.nameserver;
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
      Domains = "local"; # Allow resolving .local domains via DNS
    };
    routes = [
      {
        Gateway = config.reefNode.lan.defaultGateway;
        Metric = 10;
      }
    ];
  };

  # Wireless WAN interface - DHCP configuration (failover)
  systemd.network.networks."20-wlan" = {
    matchConfig.Name = "wlan";
    linkConfig.RequiredForOnline = "no";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    dhcpV4Config = {
      UseDNS = false;
      UseRoutes = true;
      RouteMetric = 100;
    };
  };

  # Kernel tuning
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq_codel";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    checkReversePath = "loose";
    trustedInterfaces = [
      "lan"
      "wlan"
    ];
    allowedTCPPorts = [ 22 ];
    allowPing = true;
  };

  # Ensure iwd starts before systemd-networkd
  systemd.services.systemd-networkd = {
    after = [ "iwd.service" ];
    wants = [ "iwd.service" ];
  };

  # Only wait for LAN interface at boot
  systemd.services.systemd-networkd-wait-online = {
    serviceConfig.ExecStart = [
      ""
      "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --interface=lan --timeout=30"
    ];
  };
}
