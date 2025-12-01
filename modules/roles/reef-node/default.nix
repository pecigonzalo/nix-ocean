{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./networking.nix
  ];

  options = {
    reefNode = {
      wlan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "WAN WiFi interface MAC address";
          example = "e0:51:d8:1b:dd:08";
        };
        ssid = lib.mkOption {
          type = lib.types.str;
          description = "WAN WiFi SSID";
          example = "MyNetwork";
        };
        pskFile = lib.mkOption {
          type = lib.types.path;
          description = ''
            Path to iwd PSK configuration file.
            Should be in iwd's PSK format:
            [Security]
            Passphrase=your-wifi-password

            Typically provided via agenix secret path.
          '';
          example = "/run/agenix/iwd-network";
        };
      };
      lan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "LAN interface MAC address";
          example = "e0:51:d8:1b:dd:07";
        };
        address = lib.mkOption {
          type = lib.types.str;
          description = "LAN IP address";
          example = "192.168.127.10";
        };
        prefixLength = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "LAN prefix length";
        };
        defaultGateway = lib.mkOption {
          type = lib.types.str;
          description = "LAN default gateway";
          example = "192.168.127.254";
        };
        nameserver = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "LAN nameserver(s)";
          example = [ "192.168.127.254" ];
        };
      };

      # k3s cluster options
      cluster = {
        enable = lib.mkEnableOption "k3s HA cluster";

        isInitNode = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this is the first node that initializes the cluster";
        };

        initNodeAddr = lib.mkOption {
          type = lib.types.str;
          default = "https://beta.local:6443";
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
          default = [
            "traefik"
            "servicelb"
          ];
          description = "k3s components to disable";
        };
      };
    };
  };

  config = lib.mkMerge [
    # Base configuration (always enabled)
    {
      environment.systemPackages = with pkgs; [
        tailscale
        iw
        wirelesstools
      ];
    }

    # k3s configuration (conditional)
    (lib.mkIf config.reefNode.cluster.enable {
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
          ]
          ++ (map (c: "--disable=${c}") config.reefNode.cluster.disableComponents)
        );
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
    })
  ];
}
