{
  config,
  ...
}:
{
  # Load required kernel modules
  boot.kernelModules = [
    "nf_conntrack"
  ];

  # Enable systemd-networkd
  systemd.network.enable = true;
  networking.useNetworkd = true;
  networking.useDHCP = false;

  # Rename interfaces based on MAC addresses
  systemd.network.links."10-wan" = {
    matchConfig.PermanentMACAddress = config.router.wan.mac;
    linkConfig.Name = "wan";
  };
  systemd.network.links."20-lan" = {
    matchConfig.PermanentMACAddress = config.router.lan.mac;
    linkConfig.Name = "lan";
  };

  # WAN interface - DHCP configuration
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "wan";
    linkConfig.RequiredForOnline = "routable";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    dhcpV4Config = {
      UseDNS = true;
      UseRoutes = true;
    };
  };

  # Create MACVLAN bridge for LAN interface and containers
  systemd.network.netdevs."10-mv-lan-bridge" = {
    netdevConfig = {
      Name = "mv-lan-bridge";
      Kind = "macvlan";
    };

    macvlanConfig = {
      Mode = "bridge";
    };
  };

  systemd.network.networks."10-mv-lan-bridge" = {
    matchConfig.Name = "mv-lan-bridge";

    linkConfig.RequiredForOnline = "routable";

    address = [ "${config.router.lan.address}/${toString config.router.lan.prefixLength}" ];

    networkConfig = {
      BindCarrier = "lan";
      DHCP = "no";
    };
  };

  # Attach LAN interface to MACVLAN bridge
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "lan";

    linkConfig.RequiredForOnline = "carrier";

    networkConfig = {
      MACVLAN = "mv-lan-bridge";
      DHCP = "no";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
      MulticastDNS = false;
      LLMNR = false;
    };
  };

  # Router-specific kernel tuning
  boot.kernel.sysctl = {
    # Enable IP forwarding for routing
    "net.ipv4.ip_forward" = 1;
    # Connection tracking
    "net.netfilter.nf_conntrack_max" = 524288;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 3600;
    "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 30;
    # Buffer sizes for high throughput
    "net.core.rmem_default" = 262144;
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_default" = 262144;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 87380 33554432";
    "net.ipv4.tcp_wmem" = "4096 65536 33554432";
    # Performance tuning
    "net.core.default_qdisc" = "fq_codel";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fin_timeout" = 15;
    # ARP/neighbor table tuning
    "net.ipv4.neigh.default.gc_thresh1" = 1024;
    "net.ipv4.neigh.default.gc_thresh2" = 2048;
    "net.ipv4.neigh.default.gc_thresh3" = 4096;
  };

  # DNS configuration
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
  ];

  # NAT configuration (works with systemd-networkd)
  networking.nat = {
    enable = true;
    internalInterfaces = [
      "mv-lan-bridge"
      "tailscale0"
    ];
    externalInterface = "wan";
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "mv-lan-bridge"
      "tailscale0"
    ];
    checkReversePath = "loose";
    allowPing = true;
  };
}
