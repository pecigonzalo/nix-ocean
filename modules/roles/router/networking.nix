{
  config,
  ...
}:
{
  # Load required kernel modules
  boot.kernelModules = [
    "tcp_bbr"
    "nf_conntrack"
  ];

  systemd.network.links."10-wan" = {
    matchConfig.PermanentMACAddress = config.router.wan.mac;
    linkConfig.Name = "wan";
  };
  systemd.network.links."10-lan" = {
    matchConfig.PermanentMACAddress = config.router.lan.mac;
    linkConfig.Name = "lan";
  };

  boot.kernel.sysctl = {
    "net.netfilter.nf_conntrack_max" = 524288;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 3600;
    "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 30;
    "net.core.rmem_default" = 262144;
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_default" = 262144;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 87380 33554432";
    "net.ipv4.tcp_wmem" = "4096 65536 33554432";
    "net.core.default_qdisc" = "fq_codel";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fin_timeout" = 15;
    "net.ipv4.tcp_tw_reuse" = 0;
    "net.ipv4.neigh.default.gc_thresh1" = 1024;
    "net.ipv4.neigh.default.gc_thresh2" = 2048;
    "net.ipv4.neigh.default.gc_thresh3" = 4096;
  };

  networking = {
    networkmanager.enable = false;
    useDHCP = false;

    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];

    interfaces = {
      wan = {
        useDHCP = true;
        ipv4.addresses = [
          {
            address = config.router.wan.address;
            prefixLength = config.router.wan.prefixLength;
          }
        ];
      };
      lan = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = config.router.lan.address;
            prefixLength = config.router.lan.prefixLength;
          }
        ];
      };
    };

    nat = {
      enable = true;
      internalInterfaces = [
        "lan"
        "tailscale0"
      ];
      externalInterface = "wan";
    };

    firewall = {
      enable = true;
      trustedInterfaces = [
        "tailscale0"
        "lan"
      ];
      checkReversePath = "loose";
      allowPing = true;
    };
  };
}
