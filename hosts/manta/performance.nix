{ ... }:
{
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 10;
  };

  boot.kernel.sysctl = {
    "fs.file-max" = 2097152;
    "kernel.task_delayacct" = 1;
    "net.core.default_qdisc" = "fq";
    "net.core.netdev_max_backlog" = 65536;
    "net.core.optmem_max" = 2097152;
    "net.core.rmem_default" = 524288;
    "net.core.rmem_max" = 33554432;
    "net.core.somaxconn" = 4096;
    "net.core.wmem_default" = 524288;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.ip_local_port_range" = "16384 65535";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fin_timeout" = 30;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv4.tcp_keepalive_probes" = 8;
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_max_syn_backlog" = 30000;
    "net.ipv4.tcp_max_tw_buckets" = 1440000;
    "net.ipv4.tcp_mem" = "65536 131072 262144";
    "net.ipv4.tcp_wmem" = "8192 65536 16777216";
    "net.ipv4.tcp_rmem" = "8192 87380 16777216";
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_synack_retries" = 4;
    "net.ipv4.udp_mem" = "32768 65536 131072";
    "net.ipv4.udp_rmem_min" = 4096;
    "net.ipv4.udp_wmem_min" = 4096;
    "net.netfilter.nf_conntrack_generic_timeout" = 60;
    "net.netfilter.nf_conntrack_max" = 1048576;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 1800;
    "vm.dirty_background_ratio" = 10;
    "vm.dirty_ratio" = 15;
    "vm.swappiness" = 10;
  };
}
