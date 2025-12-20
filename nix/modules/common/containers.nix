{ config, lib, ... }:
{
  options.containers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.memoryLimit = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Systemd MemoryMax for this container.";
        };
      }
    );
  };
  config.systemd.services = lib.mapAttrs' (name: cfg: {
    name = "container@${name}";
    value = lib.mkIf (cfg.memoryLimit != null) {
      serviceConfig.MemoryMax = cfg.memoryLimit;
    };
  }) config.containers;
}
