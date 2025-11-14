{
  pkgs,
  config,
  lib,
  ...
}:
{
  options = {
    router = {
      wan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "WAN interface MAC address";
        };
        address = lib.mkOption {
          type = lib.types.str;
          description = "WAN static IP address";
        };
        prefixLength = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "WAN prefix length";
        };
      };
      lan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "LAN interface MAC address";
        };
        address = lib.mkOption {
          type = lib.types.str;
          description = "LAN IP address";
        };
        prefixLength = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "LAN prefix length";
        };
      };
      tailscale = {
        authKey = lib.mkOption {
          type = lib.types.str;
          description = "Tailscale auth key";
        };
        routes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Routes to advertise";
        };
      };
      services = {
        pihole = {
          enable = lib.mkEnableOption "Pi-hole DNS and DHCP server";
          password = lib.mkOption {
            type = lib.types.str;
            description = "Pi-hole web interface password";
          };
          dhcpRange = {
            start = lib.mkOption {
              type = lib.types.str;
              description = "DHCP range start address";
            };
            end = lib.mkOption {
              type = lib.types.str;
              description = "DHCP range end address";
            };
          };
          dhcpHosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Static DHCP host mappings (MAC,IP,NAME)";
          };
          dnsHosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Custom DNS host mappings (NAME IP)";
          };
          upstreams = lib.mkOption {
            type = lib.types.str;
            default = "1.1.1.1;8.8.8.8";
            description = "Upstream DNS servers";
          };
        };
        homeAssistant = {
          enable = lib.mkEnableOption "Home Assistant";
          zigbeeDevice = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Zigbee USB device path";
          };
        };
      };
    };
  };

  config = {
    # Load required kernel modules
    boot.kernelModules = [
      "tcp_bbr" # BBR congestion control
      "nf_conntrack" # Connection tracking
    ];
    # Network interface naming
    systemd.network.links."10-wan" = {
      matchConfig.PermanentMACAddress = config.router.wan.mac;
      linkConfig.Name = "wan";
    };
    systemd.network.links."10-lan" = {
      matchConfig.PermanentMACAddress = config.router.lan.mac;
      linkConfig.Name = "lan";
    };

    # Router-specific sysctl optimizations
    boot.kernel.sysctl = {
      # Connection tracking for NAT - increase for many devices
      "net.netfilter.nf_conntrack_max" = 262144;
      "net.netfilter.nf_conntrack_tcp_timeout_established" = 86400; # 24 hours
      "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 30;

      # TCP buffer sizes - balanced for home router
      "net.core.rmem_default" = 262144;
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_default" = 262144;
      "net.core.wmem_max" = 16777216;
      "net.ipv4.tcp_rmem" = "4096 87380 16777216";
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";

      # Enable TCP BBR congestion control for better throughput
      "net.core.default_qdisc" = "fq_codel";
      "net.ipv4.tcp_congestion_control" = "bbr";

      # Reduce TCP time-wait
      "net.ipv4.tcp_fin_timeout" = 15;
      "net.ipv4.tcp_tw_reuse" = 1;

      # ARP cache tuning for many devices (IoT, Home Assistant, etc)
      "net.ipv4.neigh.default.gc_thresh1" = 1024;
      "net.ipv4.neigh.default.gc_thresh2" = 2048;
      "net.ipv4.neigh.default.gc_thresh3" = 4096;
    };

    networking = {
      networkmanager.enable = false;
      useDHCP = false;

      nameservers = [
        "8.8.8.8"
        "1.1.1.1"
      ];

      interfaces = {
        wan = {
          useDHCP = true;
          ipv4.addresses = [
            {
              address = config.router.wan.address;
              prefixLength = config.router.wan.prefixLength;
            }
          ];
        };
        lan = {
          useDHCP = false;
          ipv4.addresses = [
            {
              address = config.router.lan.address;
              prefixLength = config.router.lan.prefixLength;
            }
          ];
        };
      };

      nat = {
        enable = true;
        internalInterfaces = [
          "lan"
          "tailscale0"
        ];
        externalInterface = "wan";
      };

      firewall = {
        enable = true;
        trustedInterfaces = [
          "tailscale0"
          "lan"
        ];
        checkReversePath = "loose";
        allowPing = true;
      };
    };

    # Tailscale configuration
    environment.systemPackages = [ pkgs.tailscale ];
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
      extraSetFlags = [
        "--advertise-exit-node"
      ]
      ++ (lib.optional (
        config.router.tailscale.routes != [ ]
      ) "--advertise-routes=${lib.concatStringsSep "," config.router.tailscale.routes}");
    };

    systemd.services.tailscaled-autoconnect = {
      description = "Automatic connection to Tailscale";
      after = [
        "network-pre.target"
        "tailscaled.service"
      ];
      wants = [
        "network-pre.target"
        "tailscaled.service"
      ];
      before = [ "tailscaled-set.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";

      script = with pkgs; ''
        sleep 2

        # Check if already running and configured
        status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
        if [ "$status" = "Running" ]; then
          echo "Tailscale is already configured correctly, skipping."
          exit 0
        fi

        # Not running or not configured, connect with all settings
        # Note: This will fail if the auth key has already been used
        # In that case, manual intervention is needed or use a reusable key
        echo "Tailscale is running but not fully configured, will reconfigure..."
        ${tailscale}/bin/tailscale up --authkey ${config.router.tailscale.authKey} ${lib.concatStringsSep " " config.services.tailscale.extraSetFlags} || {
          echo "Failed to connect. If auth key expired, update config with new key or use 'tailscale up' manually."
          exit 1
        }
      '';
    };

    # Container services for router
    virtualisation.podman =
      lib.mkIf (config.router.services.pihole.enable || config.router.services.homeAssistant.enable)
        {
          enable = true;
          dockerCompat = true;
        };

    # Firewall rules for router services
    networking.firewall.interfaces.lan.allowedTCPPorts =
      (lib.optionals config.router.services.pihole.enable [ 80 ])
      ++ (lib.optionals config.router.services.homeAssistant.enable [ 8123 ]);

    networking.firewall.interfaces.lan.allowedUDPPorts =
      lib.optionals config.router.services.pihole.enable
        [
          53
          67
          68
        ];

    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      (lib.optionals config.router.services.pihole.enable [ 80 ])
      ++ (lib.optionals config.router.services.homeAssistant.enable [ 8123 ]);

    networking.firewall.interfaces.tailscale0.allowedUDPPorts =
      lib.optionals config.router.services.pihole.enable
        [
          53
          67
          68
        ];

    # Pi-hole DNS and DHCP server
    virtualisation.oci-containers.containers.pihole = lib.mkIf config.router.services.pihole.enable {
      image = "pihole/pihole:latest";
      extraOptions = [ "--memory=256m" ];
      networks = [ "host" ];
      privileged = true;
      environment = {
        FTLCONF_webserver_api_password = config.router.services.pihole.password;
        FTLCONF_dns_blocking_mode = "NODATA";
        FTLCONF_dns_interface = "lan";
        FTLCONF_dns_listeningMode = "LOCAL";
        FTLCONF_dns_upstreams = config.router.services.pihole.upstreams;
        FTLCONF_dns_bogusPriv = "true";
        FTLCONF_dns_domainNeeded = "true";
        FTLCONF_dns_hosts = lib.concatStringsSep ";" config.router.services.pihole.dnsHosts;
        FTLCONF_dhcp_active = "true";
        FTLCONF_dhcp_ipv6 = "true";
        FTLCONF_dhcp_rapidCommit = "true";
        FTLCONF_dhcp_start = config.router.services.pihole.dhcpRange.start;
        FTLCONF_dhcp_end = config.router.services.pihole.dhcpRange.end;
        FTLCONF_dhcp_router = config.router.lan.address;
        FTLCONF_dhcp_hosts = lib.concatStringsSep ";" config.router.services.pihole.dhcpHosts;
      };
      volumes = [ "/etc/pihole:/etc/pihole" ];
    };

    # Home Assistant
    virtualisation.oci-containers.containers.matter-server = {
      image = "ghcr.io/matter-js/python-matter-server:stable";
      extraOptions = [ "--memory=128m" ];
      networks = [ "host" ];
      volumes = [
        "data:/data"
        "/run/dbus:/run/dbus:ro"
      ];
    };

    virtualisation.oci-containers.containers.home-assistant =
      lib.mkIf config.router.services.homeAssistant.enable
        {
          image = "ghcr.io/home-assistant/home-assistant:stable";
          extraOptions = [ "--memory=1024m" ];
          networks = [ "host" ];
          privileged = true;
          capabilities = {
            NET_RAW = true;
            NET_ADMIN = true;
          };
          devices = lib.optional (
            config.router.services.homeAssistant.zigbeeDevice != null
          ) "${config.router.services.homeAssistant.zigbeeDevice}:/dev/ttyUSB0";
          volumes = [
            "/etc/home-assistant/:/config"
            "/run/dbus:/run/dbus:ro"
          ];
        };
  };
}
