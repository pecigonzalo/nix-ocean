{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.router.observability.speedtest;

  iperf3ExporterPackage =
    let
      version = "1.3.1";
      sources = {
        x86_64-linux = {
          arch = "amd64";
          hash = "sha256-bamelfk/oCgJokvnSPKsztVEYvHshPNllyizCU13rLA=";
        };
        aarch64-linux = {
          arch = "arm64";
          hash = "sha256-G8YLo95o7Ybg0HLsdp4Cp+Fx9/6jzHdZf7/PjAaDlcE=";
        };
      };
      source = sources.${pkgs.stdenv.hostPlatform.system} or (throw "iperf3_exporter is not packaged for ${pkgs.stdenv.hostPlatform.system}");
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "iperf3-exporter";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://github.com/edgard/iperf3_exporter/releases/download/${version}/iperf3_exporter-${version}-linux-${source.arch}.tar.gz";
        inherit (source) hash;
      };

      nativeBuildInputs = [ pkgs.makeWrapper ];
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        install -Dm755 iperf3_exporter "$out/bin/iperf3_exporter"
        wrapProgram "$out/bin/iperf3_exporter" \
          --prefix PATH : ${lib.makeBinPath [ pkgs.iperf3 ]}
        runHook postInstall
      '';

      meta = {
        description = "Prometheus exporter for probing iperf3 endpoints";
        homepage = "https://github.com/edgard/iperf3_exporter";
        license = lib.licenses.asl20;
        platforms = builtins.attrNames sources;
        mainProgram = "iperf3_exporter";
      };
    };

  targetType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Stable Prometheus label for this target.";
        example = "scaleway_fr";
      };
      host = lib.mkOption {
        type = lib.types.str;
        description = "Public iperf3 server hostname or address.";
        example = "ping.online.net";
      };
      uploadPort = lib.mkOption {
        type = lib.types.port;
        description = "iperf3 port to probe for upload tests.";
        example = 5200;
      };
      downloadPort = lib.mkOption {
        type = lib.types.port;
        description = "iperf3 port to probe for download tests.";
        example = 5201;
      };
    };
  };

  mkScrapeConfig =
    target: port: direction: reverseMode:
    {
      job_name = "speedtest_iperf3_${target.name}_${toString port}_${direction}";
      metrics_path = "/probe";
      scrape_interval = cfg.interval;
      scrape_timeout = cfg.scrapeTimeout;
      params = {
        port = [ (toString port) ];
        period = [ "${toString cfg.durationSeconds}s" ];
        reverse_mode = [ (if reverseMode then "true" else "false") ];
      };
      static_configs = [
        {
          targets = [ target.host ];
          labels = {
            speedtest_target = target.name;
            inherit direction;
          };
        }
      ];
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "${cfg.listenAddress}:${toString cfg.port}";
        }
      ];
    };

  scrapeConfigs = lib.concatMap (target: [
    (mkScrapeConfig target target.uploadPort "upload" false)
    (mkScrapeConfig target target.downloadPort "download" true)
  ]) cfg.targets;
in
{
  options.router.observability.speedtest = {
    enable = lib.mkEnableOption "public iperf3 speedtest metrics";

    package = lib.mkOption {
      type = lib.types.package;
      default = iperf3ExporterPackage;
      description = "iperf3 exporter package to run.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address where the local iperf3 exporter listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9579;
      description = "Port where the local iperf3 exporter listens.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "6h";
      description = "Prometheus scrape interval for iperf3 speedtest probes.";
    };

    scrapeTimeout = lib.mkOption {
      type = lib.types.str;
      default = "45s";
      description = "Prometheus scrape timeout for each iperf3 probe.";
    };

    durationSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Seconds to spend on each iperf3 probe.";
    };

    commandTimeout = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "Maximum timeout enforced by the iperf3 exporter.";
    };

    targets = lib.mkOption {
      type = lib.types.listOf targetType;
      default = [
        {
          name = "scaleway_fr";
          host = "ping.online.net";
          uploadPort = 5200;
          downloadPort = 5201;
        }
      ];
      description = "Public iperf3 targets to probe.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.targets != [ ];
        message = "router.observability.speedtest.targets must not be empty.";
      }
      {
        assertion = lib.all (target: target.uploadPort != target.downloadPort) cfg.targets;
        message = "router.observability.speedtest uploadPort and downloadPort should differ to avoid concurrent probes against one public iperf3 process.";
      }
      {
        assertion = lib.all (target: builtins.match "[A-Za-z0-9_]+" target.name != null) cfg.targets;
        message = "router.observability.speedtest target names may only contain letters, numbers, and underscores.";
      }
    ];

    systemd.services.iperf3-exporter = {
      description = "Prometheus iperf3 exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/iperf3_exporter --web.listen-address=${cfg.listenAddress}:${toString cfg.port} --iperf3.timeout=${cfg.commandTimeout}";
        Restart = "always";
        RestartSec = "10s";
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = [ "" ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
      };
    };

    services.prometheus.scrapeConfigs = scrapeConfigs;
  };
}
