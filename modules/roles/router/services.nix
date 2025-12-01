{
  lib,
  config,
  ...
}:
{
  virtualisation.podman =
    lib.mkIf (config.router.services.pihole.enable || config.router.services.homeAssistant.enable)
      {
        enable = true;
        dockerCompat = true;
      };

  # Firewall rules for router services
  # Note: lan and tailscale0 are already in trustedInterfaces (networking.nix)
  # so these rules are redundant but kept for explicitness
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

  virtualisation.oci-containers.containers.pihole = lib.mkIf config.router.services.pihole.enable {
    image = "pihole/pihole:latest";
    extraOptions = [ "--memory=256m" ];
    networks = [ "host" ];
    privileged = true;
    environmentFiles = [
      config.router.services.pihole.secretsFile
    ];
    environment = {
      FTLCONF_dns_upstreams = config.router.services.pihole.upstreams;
      FTLCONF_dns_blocking_mode = "NODATA";
      FTLCONF_dns_interface = "lan";
      FTLCONF_dns_listeningMode = "ALL";
      FTLCONF_dns_bogusPriv = "true";
      FTLCONF_dns_domainNeeded = "true";
      FTLCONF_dns_expandHosts = "true";
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
}
