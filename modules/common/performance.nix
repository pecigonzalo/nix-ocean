{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  perfCfg = config.ocean.performance;
in
{
  options.ocean.performance.cpuGovernor = mkOption {
    type = types.str;
    default = "schedutil"; # Modern default governor
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
      cpuFreqGovernor = lib.mkDefault perfCfg.cpuGovernor;
    };
  };
}
