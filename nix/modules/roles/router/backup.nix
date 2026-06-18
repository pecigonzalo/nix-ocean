{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.router.services.backup;
in
{
  options.router.services.backup = {
    enable = lib.mkEnableOption "Enable backup services";

    address = lib.mkOption {
      type = lib.types.str;
      description = "Syncthing backup service address";
    };

    syncthing = {
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/srv/backup/syncthing";
        description = "Host directory mounted as Syncthing's data directory.";
      };
    };

    rclone = {
      configFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to the rclone configuration file used by restic.";
      };

      remote = lib.mkOption {
        type = lib.types.str;
        default = "gdrive";
        description = "rclone remote name for the restic repository.";
      };

      repositoryPath = lib.mkOption {
        type = lib.types.str;
        default = "restic/${config.networking.hostName}";
        description = "Path under the rclone remote for the restic repository.";
      };

      options = lib.mkOption {
        type = lib.types.attrsOf (lib.types.oneOf [
          lib.types.str
          lib.types.bool
        ]);
        default = { };
        description = "Options passed to rclone by restic.";
      };
    };

    restic = {
      enable = lib.mkEnableOption "Enable restic backups" // {
        default = true;
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to the restic repository password file.";
      };

      initialize = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Initialize the restic repository if it does not exist.";
      };

      repository = lib.mkOption {
        type = lib.types.str;
        default = "rclone:${cfg.rclone.remote}:${cfg.rclone.repositoryPath}";
        description = "Restic repository URI.";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ cfg.syncthing.dataDir ];
        description = "Paths backed up by restic.";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "**/.DS_Store"
          "**/.cache"
          "**/.direnv"
          "**/.mypy_cache"
          "**/.next"
          "**/.pytest_cache"
          "**/.terraform"
          "**/.turbo"
          "**/.venv"
          "**/__pycache__"
          "**/build"
          "**/dist"
          "**/node_modules"
          "**/result"
          "**/target"
          "*.log"
        ];
        description = "Restic exclude patterns for common generated/cache paths.";
      };

      pruneOpts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        description = "Restic forget/prune retention options.";
      };

      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra restic backend options.";
      };

      timerConfig = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
        description = "systemd timer configuration for the restic backup.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.restic.enable || cfg.rclone.configFile != null;
        message = "router.services.backup.rclone.configFile must be set when restic backups are enabled.";
      }
      {
        assertion = !cfg.restic.enable || cfg.restic.passwordFile != null;
        message = "router.services.backup.restic.passwordFile must be set when restic backups are enabled.";
      }
    ];

    environment.systemPackages = with pkgs; [
      rclone
      restic
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.syncthing.dataDir} 0755 root root - -"
    ];

    containers.syncthing = {
      autoStart = true;

      macvlans = [ "lan" ];
      privateNetwork = true;
      memoryLimit = "512M";

      bindMounts."/var/lib/syncthing" = {
        hostPath = cfg.syncthing.dataDir;
        isReadOnly = false;
      };

      config =
        { ... }:
        {
          imports = [ ../../common/server-tools.nix ];
          system.stateVersion = "25.05";

          networking = {
            useDHCP = false;
            useNetworkd = true;
            useHostResolvConf = false;
            nameservers = [ config.router.services.dns.address ];
          };
          systemd.network = {
            enable = true;
            networks."10-lan" = {
              matchConfig.Name = "mv-lan";
              linkConfig.RequiredForOnline = "routable";
              address = [ "${cfg.address}/24" ];
              gateway = [ config.router.lan.address ];
            };
          };

          networking.firewall = {
            allowedTCPPorts = [
              8384
              22000
            ];
            allowedUDPPorts = [
              21027
              22000
            ];
          };

          services.syncthing = {
            enable = true;
            dataDir = "/var/lib/syncthing";
            guiAddress = "0.0.0.0:8384";
            openDefaultPorts = false;

            # Keep peer and folder configuration mutable so trusted clients can be
            # added after reading mako's generated device ID.
            overrideDevices = false;
            overrideFolders = false;

            settings.options = {
              globalAnnounceEnabled = false;
              localAnnounceEnabled = true;
              natEnabled = false;
              relaysEnabled = false;
              urAccepted = -1;
            };
          };
        };
    };

    services.restic.backups.syncthing = lib.mkIf cfg.restic.enable {
      initialize = cfg.restic.initialize;
      repository = cfg.restic.repository;
      passwordFile = cfg.restic.passwordFile;
      rcloneConfigFile = cfg.rclone.configFile;
      rcloneOptions = cfg.rclone.options;
      extraOptions = [ "rclone.program=${pkgs.rclone}/bin/rclone" ] ++ cfg.restic.extraOptions;
      paths = cfg.restic.paths;
      exclude = cfg.restic.exclude;
      pruneOpts = cfg.restic.pruneOpts;
      timerConfig = cfg.restic.timerConfig;
    };
  };
}
