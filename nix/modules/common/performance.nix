{ config, lib, ... }:
{
    # Modern kernel parameters for better performance
    boot.kernelParams = [
      "transparent_hugepage=madvise" # Use madvise instead of always for better control
      "mitigations=auto" # Security vs performance balance
    ];

    # IRQ balancing for better CPU utilization across cores
    services.irqbalance.enable = lib.mkDefault true;

    # Modern CPU frequency scaling
    powerManagement = {
      enable = true;
    };

    # Kernel sysctl tuning for networking performance
    boot.kernel.sysctl = {
      # Buffer sizes for high throughput
      "net.core.rmem_default" = lib.mkDefault 262144;
      "net.core.rmem_max" = lib.mkDefault 33554432;
      "net.core.wmem_default" = lib.mkDefault 262144;
      "net.core.wmem_max" = lib.mkDefault 33554432;
      "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 33554432";
      "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 33554432";
      # Performance tuning
      "net.core.default_qdisc" = lib.mkDefault "cake";
      "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
    };
}
