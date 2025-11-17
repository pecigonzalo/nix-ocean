{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  perfCfg = config.ocean.performance;
in
{
  options.ocean.performance.cpuGovernor = mkOption {
    type = types.str;
    default = "schedutil";
    description = "Default CPU frequency governor for hosts.";
    example = "ondemand";
  };

  config = {
    # Modern kernel parameters for better performance
    boot.kernelParams = [
      "transparent_hugepage=madvise" # Use madvise instead of always for better control
      "mitigations=auto" # Security vs performance balance
    ];

    # IRQ balancing for better CPU utilization across cores
    services.irqbalance.enable = true;

    # Modern CPU frequency scaling
    powerManagement = {
      enable = true;
      cpuFreqGovernor = lib.mkDefault perfCfg.cpuGovernor; # Best for modern CPUs with HWP
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
  };
}
