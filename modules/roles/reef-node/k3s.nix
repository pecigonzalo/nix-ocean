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
      manifests = {
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
                additionalArguments = [
                  "--api"
                  "--api.dashboard=true"
                  "--api.insecure=true"
                ];
                ingressRoute.dashboard = {
                  enabled = true;
                  entryPoints = [ "traefik" ];
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
            spec = {
              stripPrefixRegex = {
                regex = [ "^/[^/]+" ];
              };
            };
          };
        };
        podinfo = {
          target = "podinfo.yaml";
          content = {
            apiVersion = "helm.cattle.io/v1";
            kind = "HelmChart";
            metadata = {
              name = "podinfo";
              namespace = "default";
            };
            spec = {
              chart = "podinfo";
              repo = "https://stefanprodan.github.io/podinfo";
              version = "6.9.3";
              valuesContent = builtins.toJSON {
                replicaCount = 2;
                ingress = {
                  enabled = true;
                  annotations = {
                    "traefik.ingress.kubernetes.io/router.middlewares" = "default-stripprefix@kubernetescrd";
                  };
                  hosts = [
                    {
                      host = "podinfo.k3s.local";
                      paths = [
                        {
                          path = "/";
                          pathType = "ImplementationSpecific";
                        }
                      ];
                    }
                    {
                      paths = [
                        {
                          path = "/podinfo";
                          pathType = "ImplementationSpecific";
                        }
                      ];
                    }
                  ];
                };
              };
            };
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

    systemd.services.k3s.serviceConfig.TimeoutStartSec = "300s";
  };
}
