{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    reefNode = {
      cluster = {
        enable = lib.mkEnableOption "k3s HA cluster";

        isInitNode = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this is the first node that initializes the cluster";
        };

        initNodeAddr = lib.mkOption {
          type = lib.types.str;
          default = "https://192.168.127.10:6443";
          description = "Address of the initial server node";
        };

        tokenFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to k3s cluster token (agenix secret)";
        };

        clusterCidr = lib.mkOption {
          type = lib.types.str;
          default = "10.42.0.0/16";
          description = "CIDR range for pod network";
        };

        serviceCidr = lib.mkOption {
          type = lib.types.str;
          default = "10.43.0.0/16";
          description = "CIDR range for service network";
        };

        disableComponents = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "k3s components to disable";
        };
      };
    };
  };

  config = lib.mkIf config.reefNode.cluster.enable {
    services.k3s = {
      enable = true;
      gracefulNodeShutdown = {
        enable = true;
        shutdownGracePeriod = "10m";
        shutdownGracePeriodCriticalPods = "5m";
      };
      role = "server";
      tokenFile = config.reefNode.cluster.tokenFile;
      serverAddr = lib.mkIf (!config.reefNode.cluster.isInitNode) config.reefNode.cluster.initNodeAddr;

      extraFlags = toString (
        [
          "--cluster-init"
          "--cluster-cidr=${config.reefNode.cluster.clusterCidr}"
          "--service-cidr=${config.reefNode.cluster.serviceCidr}"
          "--write-kubeconfig-mode=644"
          "--node-ip=${config.reefNode.lan.address}"
          "--flannel-iface=lan"
          "--tls-san=${config.networking.hostName}"
          "--tls-san=${config.networking.hostName}.local"
          "--tls-san=${config.reefNode.lan.address}"
          "--tls-san=api.k3s.local"
        ]
        ++ (map (c: "--disable=${c}") config.reefNode.cluster.disableComponents)
      );

      # WARN: Manifests are handled with tmpfile manager, they don't get removed until reboot
      manifests = lib.mkIf config.reefNode.cluster.isInitNode {
        traefikConfig = {
          target = "traefik-config.yaml";
          content = {
            apiVersion = "helm.cattle.io/v1";
            kind = "HelmChartConfig";
            metadata = {
              name = "traefik";
              namespace = "kube-system";
            };
            spec = {
              valuesContent = builtins.toJSON {
                # Only use web and websecure entrypoints by default
                ports = {
                  web.asDefault = true;
                  websecure.asDefault = true;
                };
                ingressRoute.dashboard = {
                  enabled = true;
                  entryPoints = [ "traefik" ];
                };
                logs = {
                  access = {
                    enabled = true;
                    # Performance
                    bufferingSize = 100;
                    # Noise Reduction
                    filters = {
                      retryattempts = true;
                      # 200-299 is okay, but often dropped to save space in high-traffic apps
                      statuscodes = "400-499,500-599";
                    };
                  };
                };
                # NOTE: Enabling requires setting a OTLP endpoint
                tracing = {
                  enabled = true;
                };
              };
            };
          };
        };
        traefikMiddlewareStripPrefix = {
          target = "traefik-middleware-stripprefix.yaml";
          content = {
            apiVersion = "traefik.io/v1alpha1";
            kind = "Middleware";
            metadata = {
              name = "stripprefix";
              namespace = "default";
            };
            spec.stripPrefixRegex.regex = [ "^/[^/]+" ];
          };
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [
        6443
        10250
        2379
        2380
      ];
      allowedTCPPortRanges = [
        {
          from = 30000;
          to = 32767;
        }
      ];
      allowedUDPPorts = [ 8472 ];
    };

    boot.kernelModules = [
      "br_netfilter"
      "overlay"
      "xt_conntrack"
    ];

    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
      "fs.inotify.max_user_instances" = 524288;
      "fs.inotify.max_user_watches" = 524288;
    };

    environment.systemPackages = with pkgs; [
      k3s
      kubectl
      kubernetes-helm
      jq
    ];

    environment.sessionVariables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };
}
