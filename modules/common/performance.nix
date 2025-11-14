{ config, lib, ... }:
{
  # Modern kernel parameters for better performance
  boot.kernelParams = [
    "transparent_hugepage=madvise" # Use madvise instead of always for better control
    "mitigations=auto" # Security vs performance balance
  ];

  # Enable kernel samepage merging (KSM) for memory deduplication
  hardware.ksm = {
    enable = true;
    sleep = 20; # milliseconds between scans
  };

  # IRQ balancing for better CPU utilization across cores
  services.irqbalance.enable = true;

  # Intel N150 Alder Lake-N optimizations
  services.thermald.enable = true;

  # Modern CPU frequency scaling
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "schedutil"; # Best for modern CPUs with HWP
  };

  # zram swap for memory compression - optimized for cluster workloads
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Higher for containerized workloads
    algorithm = "zstd"; # Best compression/speed ratio
    priority = 10; # Higher priority than disk swap
  };

  # Enable SSD trimming for better disk performance and longevity
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # Modern I/O scheduler (automatic selection based on disk type)
  # NixOS already does this automatically via udev rules

  # Systemd optimizations
  systemd = {
    # Reduce shutdown timeout
    extraConfig = ''
      DefaultTimeoutStopSec=10s
      DefaultTimeoutStartSec=10s
    '';

    # Optimize service startup
    services = {
      # Make networkd and resolved wait for online faster
      systemd-networkd-wait-online.serviceConfig.ExecStart = [
        ""
        "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --any"
      ];
    };
  };
}
