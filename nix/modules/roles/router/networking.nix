{
  config,
  lib,
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

  # Create a real Linux bridge for the LAN interface and containers. Unlike a
  # macvlan, a bridge forwards multicast between the physical LAN and every
  # container veth, which mDNS-based discovery (Matter/Thread) depends on.
  # Multicast snooping is disabled so mDNS floods to all bridge ports even
  # without an IGMP/MLD querier on the segment.
  systemd.network.netdevs."10-br-lan" = {
    netdevConfig = {
      Name = "br-lan";
      Kind = "bridge";
    };
    bridgeConfig = {
      MulticastSnooping = false;
      STP = false;
    };
  };

  systemd.network.networks."10-br-lan" = {
    matchConfig.Name = "br-lan";
    linkConfig.RequiredForOnline = "routable";

    address = [
      "${config.router.lan.address}/${toString config.router.lan.prefixLength}"
      # Host holds the router address of the LAN ULA and is the IPv6 RA
      # authority (below).
      "${config.router.lan.address6}/${toString config.router.lan.prefixLength6}"
    ];

    networkConfig = {
      DHCP = "no";
      # The host is the LAN's single IPv6 RA source. It advertises the
      # fd00::/64 ULA as on-link + SLAAC so every LAN/Wi-Fi client (including
      # phones commissioning Matter/Thread) gets a routable source address.
      # OTBR then detects this on-link prefix and stops advertising its own
      # fdc9::/64, which it cannot route back from the Thread mesh. Clients
      # still learn the Thread OMR route (fd7c::/64) from OTBR's own RA.
      # Do not accept RAs here; the host is the source, not a consumer.
      IPv6AcceptRA = false;
      IPv6SendRA = true;
    };

    # No IPv6 uplink, so the host is not a default router; only announce the
    # on-link prefix (no default route). Hand out the LAN resolver over IPv6
    # (RDNSS) so IPv6-only clients get DNS without relying on IPv4 DHCP.
    ipv6SendRAConfig = {
      RouterLifetimeSec = 0;
      EmitDNS = config.router.services.dns.address6 != null;
      DNS = lib.optional (
        config.router.services.dns.address6 != null
      ) config.router.services.dns.address6;
    };

    ipv6Prefixes = [
      {
        ipv6PrefixConfig = {
          Prefix = config.router.lan.ula;
          OnLink = true;
          AddressAutoconfiguration = true;
        };
      }
    ];
  };

  # Enslave the physical LAN interface into the bridge
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "lan";
    linkConfig.RequiredForOnline = "enslaved";
    bridge = [ "br-lan" ];

    networkConfig = {
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
    allowInterfaces = [ "br-lan" ];
    nssmdns4 = true;
    nssmdns6 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Pin the CPU to full clocks. As a router running CAKE/SQM, the small idle
  # power cost is worth avoiding intel_pstate frequency-ramp latency and jitter
  # on the forwarding path. Only "performance" and "powersave" are available
  # under intel_pstate active mode.
  powerManagement.cpuFreqGovernor = "performance";

  # Router-specific kernel tuning
  boot.kernel.sysctl = {
    # Enable IP forwarding for routing (IPv4 and IPv6; IPv6 forwarding is also
    # required for the host to emit Router Advertisements on br-lan).
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
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
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "enable-rps" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        readonly cpu_count="$(${pkgs.coreutils}/bin/nproc)"
        if ((cpu_count > 32)); then
          readonly rps_mask="ffffffff"
        else
          readonly rps_mask="$(${pkgs.coreutils}/bin/printf '%x' "$(( (1 << cpu_count) - 1 ))")"
        fi

        for rps_cpus in /sys/class/net/*/queues/rx-*/rps_cpus; do
          if [[ -e "''${rps_cpus}" ]]; then
            echo "''${rps_mask}" > "''${rps_cpus}"
          fi
        done
      '';
    };
  };

  # Tune SQM for connection
  systemd.services.sqm-tuning = {
    description = "Enable CAKE SQM with bandwidth limits";
    after = [
      "network-online.target"
      "sys-subsystem-net-devices-wan.device"
    ];
    wants = [ "network-online.target" ];
    requires = [ "sys-subsystem-net-devices-wan.device" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "enable-sqm" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        readonly wan_iface="wan"
        readonly lan_iface="lan"
        readonly dl_speed="${config.router.sqm.downloadSpeed}"
        readonly ul_speed="${config.router.sqm.uploadSpeed}"

        ${pkgs.kmod}/bin/modprobe ifb
        if ! ${pkgs.iproute2}/bin/ip link show ifb0 > /dev/null 2>&1; then
          ${pkgs.iproute2}/bin/ip link add name ifb0 type ifb
        fi
        ${pkgs.iproute2}/bin/ip link set dev ifb0 up

        # Accurate shaping requires segmentation and receive offloads disabled.
        ${pkgs.ethtool}/bin/ethtool -K "''${wan_iface}" gro off gso off tso off lro off 2>/dev/null || true
        ${pkgs.ethtool}/bin/ethtool -K "''${lan_iface}" gro off gso off tso off lro off 2>/dev/null || true

        # Cleanup allows the oneshot service to be restarted safely.
        ${pkgs.iproute2}/bin/tc qdisc del dev "''${wan_iface}" root 2>/dev/null || true
        ${pkgs.iproute2}/bin/tc qdisc del dev "''${wan_iface}" ingress 2>/dev/null || true
        ${pkgs.iproute2}/bin/tc qdisc del dev ifb0 root 2>/dev/null || true

        # Apply CAKE SQM with bandwidth limits on the WAN interface and redirect ingress to ifb0
        ${pkgs.iproute2}/bin/tc qdisc add dev "''${wan_iface}" root cake bandwidth "''${ul_speed}" nat
        ${pkgs.iproute2}/bin/tc qdisc add dev "''${wan_iface}" handle ffff: ingress
        ${pkgs.iproute2}/bin/tc qdisc add dev ifb0 root cake bandwidth "''${dl_speed}" nat wash ingress
        ${pkgs.iproute2}/bin/tc filter add dev "''${wan_iface}" parent ffff: matchall action mirred egress redirect dev ifb0
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
      "br-lan"
      "tailscale0"
    ];
    externalInterface = "wan";
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "br-lan"
      "tailscale0"
    ];
    checkReversePath = "loose";
    allowPing = true;
  };
}
