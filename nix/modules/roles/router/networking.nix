{
  config,
  pkgs,
  ...
}:
{
  # Load required kernel modules
  boot.kernelModules = [
    "nf_conntrack"
    "ifb"
    "tcp_bbr"
    "act_mirred"
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

  services.avahi = {
    enable = true;
    ipv4 = true;
    ipv6 = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Router-specific kernel tuning
  boot.kernel.sysctl = {
    # Enable IP forwarding for routing
    "net.ipv4.ip_forward" = 1;
    # Connection tracking
    "net.netfilter.nf_conntrack_max" = 524288;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 3600;
    # Buffer sizes for high throughput
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 87380 33554432";
    "net.ipv4.tcp_wmem" = "4096 65536 33554432";
    # Performance tuning
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Enable RPS (Software RSS) to fix single-queue bottleneck
  systemd.services.rps-tuning = {
    description = "Enable RPS for NICs";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "enable-rps" ''
        #!${pkgs.bash}/bin/bash
        # Apply 'f' (all 4 cores) to any interface with a receive queue
        for interface in /sys/class/net/*; do
          if [ -e "$interface/queues/rx-0/rps_cpus" ]; then
            echo f > "$interface/queues/rx-0/rps_cpus"
          fi
        done
      '';
    };
  };

  # Tune SQM for connection
  systemd.services.sqm-tuning = {
    description = "Enable CAKE SQM with bandwidth limits";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "enable-sqm" ''
        #!${pkgs.bash}/bin/bash

        WAN_IFACE="wan"
        LAN_IFACE="lan"

        # Set to 90-95% of your real speed to ensure the queue stays in router
        # Example: 1Gbps link -> 900mbit or 920mbit
        DL_SPEED="900mbit"
        UL_SPEED="900mbit"

        ${pkgs.kmod}/bin/modprobe ifb
        # Create ifb0 manually if it doesn't exist
        if ! ${pkgs.iproute2}/bin/ip link show ifb0 > /dev/null 2>&1; then
            ${pkgs.iproute2}/bin/ip link add name ifb0 type ifb
        fi
        ${pkgs.iproute2}/bin/ip link set dev ifb0 up

        # Force disable LRO/GRO on the physical WAN to ensure accurate shaping
        ${pkgs.ethtool}/bin/ethtool -K $WAN_IFACE gro off gso off tso off lro off 2>/dev/null || true
        ${pkgs.ethtool}/bin/ethtool -K $LAN_IFACE gro off gso off tso off lro off 2>/dev/null || true

        # Bring ifb0 up
        ${pkgs.iproute2}/bin/ip link set dev ifb0 up

        # Cleanup
        ${pkgs.iproute2}/bin/tc qdisc del dev $WAN_IFACE root 2>/dev/null || true
        ${pkgs.iproute2}/bin/tc qdisc del dev $WAN_IFACE ingress 2>/dev/null || true
        ${pkgs.iproute2}/bin/tc qdisc del dev ifb0 root 2>/dev/null || true

        # Upload
        ${pkgs.iproute2}/bin/tc qdisc add dev $WAN_IFACE root cake bandwidth $UL_SPEED nat

        # Download
        ${pkgs.iproute2}/bin/tc qdisc add dev $WAN_IFACE handle ffff: ingress
        ${pkgs.iproute2}/bin/tc qdisc add dev ifb0 root cake bandwidth $DL_SPEED nat wash ingress

        # Redirect Ingress -> IFB0
        ${pkgs.iproute2}/bin/tc filter add dev $WAN_IFACE parent ffff: matchall action mirred egress redirect dev ifb0
      '';
    };
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
